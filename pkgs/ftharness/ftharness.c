// SPDX-License-Identifier: GPL-2.0-only
/*
 * Bring-up client for the FocalTech FT9362 fingerprint trusted application
 * ("focal32") on the Fairphone 5, over the QSEECOM TEE driver.
 *
 * This is a probe, not a fingerprint stack: it loads the application, runs the
 * init sequence the vendor HAL runs, and prints what comes back. Everything
 * past PROBE_DEVICE needs the file service the application asks the normal
 * world to run, which lives in a supplicant this does not yet implement.
 *
 *   ftharness version                    list the TEE devices and their impl
 *   ftharness load [--keep]              load focal32 and hold it loaded
 *   ftharness probe                      load, then SYNC_CONFIG -> INIT_SPI ->
 *                                        SET_SPI_SPEED -> PROBE_DEVICE ->
 *                                        INIT_DEVICE -> TRUSTLET_INIT
 *   ftharness cmd 0x100a [--arg N]       send one command and dump the reply
 *
 * Options: --app NAME (default focal32), --arg N, --req N, --rsp N, --keep.
 *
 * A request is a 16-byte ff_transfer_header_t -- command id, payload length,
 * eight bytes left zero -- followed by the payload, and the length handed to
 * the secure world is the region's capacity rather than the message's length.
 * That layout comes from the vendor HAL's ff_trustlet_client_exchange_message()
 * and from the checks the application makes in ff_trustlet_message_cb.
 *
 * Build: cc -O2 -o ftharness ftharness.c
 */

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <linux/tee.h>

/* The device only root may open: it loads applications and serves listeners. */
#define PRIV_DEV		"/dev/teepriv0"

/* This driver's TEE_IMPL_ID, which is how its client device is recognised. */
#define TEE_IMPL_ID_QSEECOM	5

#define FF_APP_NAME		"focal32"

/*
 * TA command ids, read out of the application's own dispatch table: the
 * tbh at ff_trustlet_message_cb+0x264 indexes on (cmd - 0x1004), and each
 * entry lands on a stub that tail-calls a named ff_trustlet_* function.
 *
 * These are NOT the ids you get by pairing the FF_CMD_TA_* string table with
 * 0x1004 upwards -- that assumption is wrong by up to four positions, and it
 * sends well-formed messages to the wrong handler. 0x1005 and 0x1011 are the
 * table's error entries.
 */
#define FF_CMD_TRUSTLET_INIT		0x1004
#define FF_CMD_INIT_SPI			0x1006
#define FF_CMD_FREE_SPI			0x1007
#define FF_CMD_SET_SPI_SPEED		0x1008
#define FF_CMD_PROBE_DEVICE		0x100a
#define FF_CMD_INIT_DEVICE		0x100b
#define FF_CMD_ESD_HANDLE		0x100c
#define FF_CMD_SYNC_CONFIG		0x100d
#define FF_CMD_SYNC_STATISTICS		0x100e
#define FF_CMD_START_SCANNING		0x1012
#define FF_CMD_CAPTURE_IMAGE		0x1013
#define FF_CMD_SAVE_DATA		0x1014

/*
 * How long a payload each command carries, read out of the vendor HAL's table
 * at 0x979a0 -- pairs of {command id, payload length}. The application checks
 * the length it is given, so a command sent with the wrong one is refused
 * before its payload is ever looked at.
 *
 * The payload's *contents* are not decoded here. Sending the right length with
 * zeroes is what makes a command well-formed enough to get an answer worth
 * reading; the answer is what says whether the contents mattered.
 */
static const struct { uint32_t cmd; uint32_t len; } ff_payload_len[] = {
	{ 0x1004, 0 },     { 0x1000, 0 },     { 0x1014, 4 },
	{ 0x1015, 0x2e0 }, { 0x1016, 4 },     { 0x1012, 0x30 },
	{ 0x1013, 0x24 },  { 0x1017, 0x2e0 }, { 0x2000, 0 },
	{ 0x2001, 0x4a },  { 0x2002, 0 },     { 0x2003, 0 },
	{ 0x2004, 0 },     { 0x2005, 4 },     { 0x2006, 8 },
	{ 0x2008, 0x0e },  { 0x100e, 0x230 }, { 0x1006, 0 },
	{ 0x1007, 0 },     { 0x1008, 4 },     { 0x100a, 1 },
	{ 0x100c, 0 },     { 0x1022, 0 },     { 0x1018, 8 },
	{ 0x1019, 4 },     { 0x101b, 8 },     { 0x101c, 4 },
	{ 0x101d, 4 },     { 0x1021, 4 },     { 0x1023, 0 },
	{ 0x101e, 4 },     { 0x101f, 4 },     { 0x1020, 0x24 },

	/*
	 * SYNC_TEMPLATE. Not in the HAL's constant table, because
	 * ff_trustlet_sync_template sizes its message at run time: it mallocs
	 * the template's own length plus 0x18 and sends that as the payload,
	 * with two words at the front. 0x18 is therefore what an empty template
	 * list costs, which is the case that matters on a device with nothing
	 * enrolled yet.
	 */
	{ 0x1010, 0x18 },

	/*
	 * SET_ACTIVE_GROUP, likewise sized at run time by the HAL: a group id
	 * followed by the NUL-terminated store path, so strlen(path) + 5. The
	 * application reads the id from the first word and treats the rest as a
	 * C string, so a fixed, generously sized payload with the path poked in
	 * and zero padding after it says the same thing.
	 */
	{ 0x2007, 0x40 },
};

/*
 * -1 for a command the table does not carry -- 0x100f (INIT_DEVICE) and
 * 0x1010, 0x1011, 0x1024 among them. Those are sent from somewhere else in the
 * HAL, or not at all, and guessing a length for them is how a command gets
 * refused for a reason that looks like something else.
 */
static long ff_payload_size(uint32_t cmd)
{
	size_t i;

	for (i = 0; i < sizeof(ff_payload_len) / sizeof(ff_payload_len[0]); i++)
		if (ff_payload_len[i].cmd == cmd)
			return ff_payload_len[i].len;

	return -1;
}

/*
 * INIT_DEVICE sizes its own reply as the caller's hint plus 0x38, so 0x38 is
 * the floor for any command. Give every command a page: the application is
 * free to write more than we asked for, and a short buffer is how a reply gets
 * truncated silently.
 */
#define FF_RSP_MIN		0x38
#define FF_RSP_DEFAULT		0x8040

/*
 * ff_transfer_header_t. The vendor client copies its first eight bytes into
 * the shared buffer and memcpy()s the payload to +0x10, and the application
 * checks the request region against this size before it looks at the command.
 */
#define FF_HEADER_SIZE		0x10

/*
 * Default request capacity. The vendor registers a 0x80040-byte buffer and
 * splits it into a 0x78000 request region and a 0x8040 response region; the
 * lengths it passes are those regions', not the message's. Nothing here needs
 * 480 KiB, but the capacity must exceed the header.
 */
#define FF_REQ_DEFAULT		4096

struct shm {
	int id;
	void *va;
	size_t size;
};

static int shm_alloc(int fd, size_t size, struct shm *out)
{
	struct tee_ioctl_shm_alloc_data data = { .size = size };
	int shm_fd;

	shm_fd = ioctl(fd, TEE_IOC_SHM_ALLOC, &data);
	if (shm_fd < 0) {
		fprintf(stderr, "SHM_ALLOC(%zu): %s\n", size, strerror(errno));
		return -1;
	}

	out->va = mmap(NULL, data.size, PROT_READ | PROT_WRITE, MAP_SHARED,
		       shm_fd, 0);
	close(shm_fd);
	if (out->va == MAP_FAILED) {
		fprintf(stderr, "mmap: %s\n", strerror(errno));
		return -1;
	}

	out->id = data.id;
	out->size = data.size;
	memset(out->va, 0, data.size);

	return 0;
}

/*
 * Which /dev/teeN this driver gets depends on what else registered first, and
 * qcomtee is built into the same kernel, so ask each device what it is rather
 * than hardcoding a number.
 */
static int open_client(void)
{
	struct tee_ioctl_version_data vers;
	char path[32];
	int i, fd;

	for (i = 0; i < 8; i++) {
		snprintf(path, sizeof(path), "/dev/tee%d", i);
		fd = open(path, O_RDWR);
		if (fd < 0)
			continue;

		if (!ioctl(fd, TEE_IOC_VERSION, &vers) &&
		    vers.impl_id == TEE_IMPL_ID_QSEECOM) {
			printf("client: %s\n", path);
			return fd;
		}

		close(fd);
	}

	fprintf(stderr, "no QSEECOM TEE device found -- is tee_qseecom loaded, "
			"and did qcom_scm allow this machine?\n");

	return -1;
}

static int show_version(void)
{
	struct tee_ioctl_version_data vers;
	char path[32];
	int i, fd, found = 0;

	for (i = 0; i < 8; i++) {
		snprintf(path, sizeof(path), "/dev/tee%d", i);
		fd = open(path, O_RDWR);
		if (fd < 0)
			continue;

		if (!ioctl(fd, TEE_IOC_VERSION, &vers)) {
			printf("%s: impl_id=%u%s impl_caps=0x%x gen_caps=0x%x\n",
			       path, vers.impl_id,
			       vers.impl_id == TEE_IMPL_ID_QSEECOM ?
			       " (QSEECOM)" : "",
			       vers.impl_caps, vers.gen_caps);
			found++;
		}

		close(fd);
	}

	if (!found) {
		fprintf(stderr, "no TEE device answered\n");
		return -1;
	}

	return 0;
}

/*
 * A session is opened by name, not by UUID: QSEE matches on the string, so the
 * name arrives in parameter 0 and there is nothing to render a UUID into. On
 * the privileged device the same call means "load this application"; on the
 * client device it means "attach to one already loaded".
 */
static int open_session(int fd, const char *app)
{
	struct {
		struct tee_ioctl_open_session_arg arg;
		struct tee_ioctl_param params[1];
	} sess = {};
	struct tee_ioctl_buf_data bd;
	struct shm nm;

	if (strlen(app) >= 64) {
		fprintf(stderr, "name '%s' is too long\n", app);
		return -1;
	}

	if (shm_alloc(fd, 64, &nm))
		return -1;

	strcpy(nm.va, app);

	sess.arg.num_params = 1;
	sess.params[0].attr = TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_INPUT;
	sess.params[0].a = 0;
	sess.params[0].b = strlen(app) + 1;
	sess.params[0].c = nm.id;

	bd.buf_ptr = (uintptr_t)&sess;
	bd.buf_len = sizeof(sess);

	if (ioctl(fd, TEE_IOC_OPEN_SESSION, &bd)) {
		fprintf(stderr, "OPEN_SESSION('%s'): %s\n", app,
			strerror(errno));
		return -1;
	}

	if (sess.arg.ret) {
		fprintf(stderr, "OPEN_SESSION('%s'): ret=0x%x origin=0x%x\n",
			app, sess.arg.ret, sess.arg.ret_origin);
		return -1;
	}

	return (int)sess.arg.session;
}

/*
 * Loading holds the application in TZ for as long as the session that loaded
 * it stays open: the driver unloads it when that session closes. The image
 * comes from request_firmware(), so <app>.mdt and its .bNN segments have to be
 * in the firmware search path -- not squashed into a single .mbn, which is
 * what the rest of the FP5 firmware is converted to.
 */
static int load_app(const char *app, int *out_fd)
{
	int fd, session;

	fd = open(PRIV_DEV, O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "open %s: %s%s\n", PRIV_DEV, strerror(errno),
			errno == EACCES || errno == EPERM ?
			" (needs root: the privileged device wants CAP_SYS_ADMIN)" :
			"");
		return -1;
	}

	session = open_session(fd, app);
	if (session < 0) {
		fprintf(stderr,
			"is %s.mdt, with its .bNN segments, in the firmware "
			"search path?\n", app);
		close(fd);
		return -1;
	}

	printf("loaded '%s' (load session %d)\n", app, session);
	*out_fd = fd;

	return 0;
}

/*
 * Hold the application loaded. The driver unloads it when the load session
 * closes, so something has to keep that session open for as long as the
 * application is wanted -- which is what makes this usable as a service and
 * not only as a probe. Interactively that wait is a keypress; under a service
 * manager there is nobody to press anything and stdin is /dev/null, where a
 * read returns end-of-file at once and would unload it immediately. Wait for a
 * signal instead, and let the default SIGTERM disposition end it: exiting
 * closes the session, which is the unload.
 */
static void hold_loaded(void)
{
	if (isatty(STDIN_FILENO)) {
		printf("press enter to unload\n");
		getchar();
		return;
	}

	printf("holding the application loaded until terminated\n");
	fflush(stdout);
	pause();
}

static void dump(const void *buf, size_t len)
{
	const unsigned char *p = buf;
	size_t i;

	for (i = 0; i < len; i++)
		printf("%s%02x", (i % 16) ? " " : (i ? "\n    " : "    "), p[i]);
	printf("\n");
}

/*
 * The reply's first four words, as traced out of the convergence code at
 * 0x7A38: status, then the ids and the sample count an enrollment reports.
 *
 * That shape holds for the capture and enrollment commands it was traced from.
 * It does not hold everywhere: INIT answers with a length and a banner --
 * "focaltech:ta:base", then the TA's build version -- so the words are printed
 * as raw and only 0xffffffff, which every handler's error path writes, is
 * called a refusal.
 */
static void decode(const uint32_t *r)
{
	printf("  w0=0x%08x w1=0x%08x w2=0x%08x w3=0x%08x\n",
	       r[0], r[1], r[2], r[3]);

	if (r[0] == 0xffffffff)
		printf("  -> the application refused the command\n");
}

/* Any printable run the application left in the reply. */
static void strings(const void *buf, size_t len)
{
	const unsigned char *p = buf;
	size_t i, run = 0;

	for (i = 0; i < len; i++) {
		if (p[i] >= 32 && p[i] < 127) {
			if (!run)
				printf("  +%zu: \"", i);
			run++;
			putchar(p[i]);
		} else if (run) {
			printf("\"\n");
			run = 0;
		}
	}
	if (run)
		printf("\"\n");
}

/*
 * One command. The request is a memref the driver copies into TZ memory, the
 * response a memref it copies back; the driver takes at least these two and
 * pairs after them only for addresses to patch into the request, which no
 * command here needs.
 */
static size_t req_pad;
/* Bytes of the written-back request payload to dump; 0 disables it. */
static size_t req_show;

/*
 * A string payload, for the commands that take one. SYNC_CONFIG (0x1011) is
 * the reason this exists: the vendor client strlen()s its argument and sends
 * the terminator with it, and the application parses the result as JSON --
 * json_node_t/JSON_OBJECT and a config.c sharing its key names with the HAL.
 */
static const char *req_str;

/*
 * Words to write into the payload before sending, as offset=value pairs. The
 * device descriptor PROBE_DEVICE carries is 0x230 bytes that the application
 * memcpy()s into a global and reads fields out of later; nothing here decodes
 * it, so this exists to write one word at a time and watch what changes.
 */
#define FF_MAX_POKE	40
struct poke { size_t off; uint32_t val; };
static struct poke pokes[FF_MAX_POKE];
static unsigned int npokes;

/* Commands to run in one session, as "cmd[:arg],cmd[:arg],..." */
static const char *seq_spec;

/*
 * The sensor's reset line belongs to the kernel driver, not to the trusted
 * application: the application drives the bus but cannot touch GPIOs. The
 * vendor HAL pulses reset through this ioctl around a probe, so offer the
 * same before a sequence runs.
 */
#define FF_DEV		"/dev/focaltech_fp"
#define FF_IOC_RESET	_IO('f', 0x02)

static int sensor_reset(void)
{
	int fd = open(FF_DEV, O_RDWR);

	if (fd < 0) {
		fprintf(stderr, "open %s: %s\n", FF_DEV, strerror(errno));
		return -1;
	}

	if (ioctl(fd, FF_IOC_RESET)) {
		fprintf(stderr, "reset: %s\n", strerror(errno));
		close(fd);
		return -1;
	}

	close(fd);
	printf("sensor reset\n");

	return 0;
}

/* Read a payload from a file, so a shell cannot mangle its quoting. */
static char *slurp(const char *path)
{
	long n;
	char *buf;
	FILE *f = fopen(path, "rb");

	if (!f) {
		fprintf(stderr, "open %s: %s\n", path, strerror(errno));
		return NULL;
	}

	fseek(f, 0, SEEK_END);
	n = ftell(f);
	rewind(f);

	if (n < 0 || !(buf = malloc((size_t)n + 1))) {
		fclose(f);
		return NULL;
	}

	if (fread(buf, 1, (size_t)n, f) != (size_t)n) {
		fprintf(stderr, "read %s: short\n", path);
		free(buf);
		fclose(f);
		return NULL;
	}

	fclose(f);

	/* Trim a trailing newline an editor or a shell will have added. */
	while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r'))
		n--;
	buf[n] = 0;

	return buf;
}

/*
 * The payload the last command answered with, kept so a later step in the same
 * sequence can look at it. "skipz:OFF" needs this: the application reports
 * whether a capture actually produced an image in its own payload, and a
 * sequence has to be able to act on that.
 */
#define FF_LAST_PAYLOAD	256
static uint8_t last_payload[FF_LAST_PAYLOAD];
static size_t last_payload_len;

/* The session's one shared buffer; see the comment where it is allocated. */
static struct shm shm_req, shm_rsp;
static size_t shm_req_cap, shm_rsp_cap;
static int shm_ready;

static int invoke_full(int fd, uint32_t session, uint32_t cmd_id, int have_arg,
		       uint32_t arg_val, size_t rsp_size, const char *str,
		       const struct poke *pk, unsigned int npk)
{
	struct {
		struct tee_ioctl_invoke_arg arg;
		struct tee_ioctl_param params[2];
	} buf = {};
	struct tee_ioctl_buf_data bd;
	struct shm req, rsp;
	size_t req_size = FF_REQ_DEFAULT;
	unsigned int k;

	/*
	 * The application checks the request against sizeof(ff_transfer_header_t)
	 * before it looks at the command id at all:
	 *
	 *   assertion 'g_builtin_buffer->len >= sizeof(ff_transfer_header_t)'
	 *   failed  --  ff_trustlet_message_cb[trustlet_trans.c:565]
	 *
	 * The header is not decoded yet, so --req sweeps the length until the
	 * assertion stops firing. Padding is zero, which is what an unset
	 * header field would be.
	 */
	if (req_pad)
		req_size = req_pad;

	if (rsp_size < FF_RSP_MIN)
		rsp_size = FF_RSP_MIN;

	/*
	 * One buffer for the whole session, not one per command.
	 *
	 * The application keeps pointers into this memory across commands:
	 * ff_trustlet_update_template stores a param_data pointer in a global,
	 * and ff_trustlet_capture_image asserts outright that the context it is
	 * handed *is* the vendor's own buffer --
	 *
	 *   assertion '(uint8_t *)capture_ctx == g_builtin_buffer->usr' failed
	 *
	 * -- so the HAL's ff_builtin_user_buffer_lock() hands back the same
	 * region every time. A fresh region per command leaves those pointers
	 * addressing memory the secure world no longer has, which is the shape
	 * of a fault that only appears once something dereferences what an
	 * earlier command stored.
	 */
	if (!shm_ready) {
		if (shm_alloc(fd, req_size, &shm_req) ||
		    shm_alloc(fd, rsp_size, &shm_rsp))
			return -1;
		shm_req_cap = req_size;
		shm_rsp_cap = rsp_size;
		shm_ready = 1;
	} else if (req_size > shm_req_cap || rsp_size > shm_rsp_cap) {
		fprintf(stderr,
			"0x%04x wants %zu/%zu but the session's buffer is "
			"%zu/%zu -- raise --req/--rsp so one buffer serves "
			"every command\n", cmd_id, req_size, rsp_size,
			shm_req_cap, shm_rsp_cap);
		return -1;
	}

	req = shm_req;
	rsp = shm_rsp;

	/*
	 * Only the header and this command's payload are cleared. Whatever a
	 * previous command left further into the buffer stays, which is what
	 * the vendor does -- it memsets just the context it is about to fill.
	 */
	memset(rsp.va, 0, rsp_size);

	/*
	 * ff_transfer_header_t, as the vendor client builds it in
	 * ff_trustlet_client_exchange_message() and the application checks it
	 * in the dispatcher at 0x7410: the command id, the payload length, and
	 * eight bytes the client leaves zero. The payload follows the header.
	 *
	 * The length passed to the secure world is the region's capacity, not
	 * the message's length -- the application reads it as the buffer it may
	 * work in, and rejects a payload longer than capacity minus the header.
	 */
	{
		long known = ff_payload_size(cmd_id);
		uint32_t plen = known < 0 ? (have_arg ? 4 : 0) : (uint32_t)known;

		/* A string carries its own length, terminator included. */
		if (str)
			plen = (uint32_t)strlen(str) + 1;

		if (known < 0)
			printf("  (0x%04x is not in the HAL's length table; "
			       "sending %u)\n", cmd_id, plen);

		if (FF_HEADER_SIZE + plen > req_size) {
			fprintf(stderr,
				"payload of %u needs a request capacity above %zu\n",
				plen, req_size);
			return -1;
		}

		/*
		 * The buffer is reused, so clear what this command owns --
		 * the header and its own payload. shm_alloc() used to do this
		 * by handing out fresh memory every time.
		 */
		memset(req.va, 0, FF_HEADER_SIZE + plen);

		((uint32_t *)req.va)[0] = cmd_id;
		((uint32_t *)req.va)[1] = plen;

		if (str)
			memcpy((uint8_t *)req.va + FF_HEADER_SIZE, str, plen);

		for (k = 0; k < npk; k++) {
			if (pk[k].off + 4 > plen) {
				fprintf(stderr,
					"poke at %zu is past a %u-byte payload\n",
					pk[k].off, plen);
				return -1;
			}
			*(uint32_t *)((uint8_t *)req.va + FF_HEADER_SIZE +
				      pk[k].off) = pk[k].val;
		}

		/*
		 * Payload otherwise stays zeroed by shm_alloc(). Some commands
		 * take less than a word -- INIT_SPI's payload is a single byte
		 * -- so write only as much of the argument as fits.
		 */
		if (have_arg && plen >= 4)
			*(uint32_t *)((uint8_t *)req.va + FF_HEADER_SIZE) =
				arg_val;
		else if (have_arg && plen)
			memcpy((uint8_t *)req.va + FF_HEADER_SIZE, &arg_val,
			       plen);
	}

	buf.arg.func = 0;
	buf.arg.session = session;
	buf.arg.num_params = 2;

	/*
	 * Inout, not input: the application answers in this buffer. It writes
	 * its result into the header at +8 and sets bit 31 of the command id
	 * at +0 to say so, and the driver only copies the request back when
	 * asked this way.
	 */
	buf.params[0].attr = TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_INOUT;
	buf.params[0].a = 0;
	buf.params[0].b = req_size;
	buf.params[0].c = req.id;

	buf.params[1].attr = TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_OUTPUT;
	buf.params[1].a = 0;
	buf.params[1].b = rsp_size;
	buf.params[1].c = rsp.id;

	bd.buf_ptr = (uintptr_t)&buf;
	bd.buf_len = sizeof(buf);

	if (ioctl(fd, TEE_IOC_INVOKE, &bd)) {
		fprintf(stderr, "INVOKE(0x%04x): %s\n", cmd_id,
			strerror(errno));

		/*
		 * The application writes its log into the response region as it
		 * runs, so whatever it managed before it died is still sitting
		 * there. The last line is where it got to -- the only view we
		 * have into a command that never returns.
		 */
		printf("  the application's log up to the point it died:\n");
		strings(rsp.va, rsp_size);
		fflush(stdout);
		return -1;
	}

	{
		size_t show = rsp_size > 256 ? 256 : rsp_size;
		uint32_t back = ((uint32_t *)req.va)[0];
		uint32_t result = ((uint32_t *)req.va)[2];
		size_t keep = req_size - FF_HEADER_SIZE;

		if (keep > FF_LAST_PAYLOAD)
			keep = FF_LAST_PAYLOAD;
		memcpy(last_payload, (uint8_t *)req.va + FF_HEADER_SIZE, keep);
		last_payload_len = keep;

		printf("cmd 0x%04x: arg.ret=0x%x origin=0x%x\n", cmd_id,
		       buf.arg.ret, buf.arg.ret_origin);

		/*
		 * Bit 31 set on the command id is the application saying it
		 * handled the message; without it nothing wrote here.
		 */
		if (back & 0x80000000u)
			printf("  answered: result=0x%08x (%d)\n", result,
			       (int32_t)result);
		else
			printf("  no answer written back (id reads 0x%08x)\n",
			       back);
		/*
		 * The application answers in the request buffer, and for the
		 * commands that report something -- REPORT_EVENT above all --
		 * the answer is a structure at the payload offset, not the
		 * status word. The response region carries the application's
		 * log stream instead, so this is the only place that data
		 * appears.
		 */
		if (req_show) {
			size_t room = req_size - FF_HEADER_SIZE;
			size_t n = req_show > room ? room : req_show;

			printf("  request payload[0..%zu] (written back):\n", n);
			dump((uint8_t *)req.va + FF_HEADER_SIZE, n);
		}

		decode(rsp.va);
		printf("  reply[0..%zu]:\n", show);
		dump(rsp.va, show);
		strings(rsp.va, rsp_size);
	}

	/*
	 * Only a refusal the application spells out is a failure here. arg.ret
	 * says whether the call reached it at all, and the reply's first word
	 * is not a status everywhere -- reading it as one made INIT, which
	 * answers with a banner, look like an error.
	 */
	if (buf.arg.ret)
		return 1;

	return ((uint32_t *)rsp.va)[0] == 0xffffffff ? 1 : 0;
}

static int invoke(int fd, uint32_t session, uint32_t cmd_id, int have_arg,
		  uint32_t arg_val, size_t rsp_size)
{
	return invoke_full(fd, session, cmd_id, have_arg, arg_val, rsp_size,
			   req_str, pokes, npokes);
}

/*
 * The order the vendor HAL uses. INIT_SPI is where the application takes the
 * bus, so PROBE_DEVICE before it says nothing. PROBE_DEVICE reading the chip
 * id back is the first evidence that the sensor is powered, out of reset, and
 * on the bus the application thinks it is on.
 */
static int probe(int fd, uint32_t session)
{
	static const struct {
		uint32_t cmd;
		const char *name;
		int have_arg;
		uint32_t arg;
		int fatal;
	} seq[] = {
		/*
		 * The order the application's own handlers imply. Config first:
		 * ff_spi_init reads driver.spi_bus_num out of the config tree
		 * (default 0) and only then can open the bus, so a config that
		 * arrives later cannot be what it reads.
		 *
		 * Only sent when --str/--str-file supplied one.
		 */
		{ FF_CMD_SYNC_CONFIG,	"SYNC_CONFIG",	0, 0, 0 },
		/* ff_spi_init: reads the bus from config, opens it. */
		{ FF_CMD_INIT_SPI,	"INIT_SPI",	0, 0, 1 },
		/* payload's first word is the clock in bps. */
		{ FF_CMD_SET_SPI_SPEED,	"SET_SPI_SPEED", 1, 2000000, 1 },
		/*
		 * One byte of payload. Zero is refused outright, one is taken;
		 * what it selects is not decoded.
		 */
		{ FF_CMD_PROBE_DEVICE,	"PROBE_DEVICE",	1, 1, 1 },
		/* Loads calibration; allowed to fail with none stored yet. */
		{ FF_CMD_INIT_DEVICE,	"INIT_DEVICE",	0, 0, 0 },
		/*
		 * Last: it asserts on g_device->chip.query_device_status, so a
		 * chip has to be bound by PROBE_DEVICE before this can pass.
		 */
		{ FF_CMD_TRUSTLET_INIT,	"TRUSTLET_INIT", 0, 0, 0 },
	};
	unsigned int i;

	for (i = 0; i < sizeof(seq) / sizeof(seq[0]); i++) {
		int ret;

		if (seq[i].cmd == FF_CMD_SYNC_CONFIG && !req_str) {
			printf("\n== %s: skipped, no --str/--str-file\n",
			       seq[i].name);
			continue;
		}

		printf("\n== %s\n", seq[i].name);
		ret = invoke(fd, session, seq[i].cmd, seq[i].have_arg,
			     seq[i].arg, FF_RSP_DEFAULT);
		if (ret && seq[i].fatal) {
			fprintf(stderr, "%s failed, stopping\n", seq[i].name);
			return -1;
		}
		if (ret)
			printf("  (non-fatal: %s is allowed to fail here)\n",
			       seq[i].name);
	}

	return 0;
}

/*
 * Run an arbitrary sequence in one session. Ordering is the whole question
 * here -- the application's state carries between commands, and which command
 * has to precede which is exactly what is not yet known -- so this makes the
 * order a runtime argument rather than something compiled in.
 */
static int run_seq(int fd, uint32_t session, const char *spec)
{
	char *copy = strdup(spec);
	char *save = NULL, *tok;
	int last = 0;
	int skipping = 0;

	if (!copy)
		return -1;

	for (tok = strtok_r(copy, ",", &save); tok;
	     tok = strtok_r(NULL, ",", &save)) {
		uint32_t cmd, arg = 0;
		int have = 0;
		const char *str = NULL;
		struct poke tpk[FF_MAX_POKE];
		unsigned int tnpk = 0;
		char *at, *colon, *plus;

		/*
		 * "+off=val" pokes this command only. A global --poke would
		 * land in every payload in the sequence -- overwriting a
		 * config blob and overflowing the one-byte payloads.
		 */
		while ((plus = strrchr(tok, '+')) && tnpk < FF_MAX_POKE) {
			char *eq = strchr(plus, '=');

			if (!eq)
				break;
			*plus = 0;
			tpk[tnpk].off = strtoul(plus + 1, NULL, 0);
			tpk[tnpk].val = strtoul(eq + 1, NULL, 0);
			tnpk++;
		}

		at = strchr(tok, '@');

		/*
		 * "cmd@file" gives one command a payload of its own. Without
		 * this, a --str applies to every command in the sequence --
		 * which silently sends a config blob as INIT's payload and
		 * makes the run say nothing about the command under test.
		 */
		if (at) {
			*at = 0;
			str = slurp(at + 1);
			if (!str) {
				free(copy);
				return -1;
			}
		}

		colon = strchr(tok, ':');

		if (colon) {
			*colon = 0;
			arg = strtoul(colon + 1, NULL, 0);
			have = 1;
		}

		/*
		 * "wait:N" pauses N seconds without leaving the session. The
		 * application's REPORT_EVENT only has something to report once
		 * the sensor has actually raised its interrupt, and a finger
		 * arrives on human time -- so the wait has to happen between
		 * two commands of the same session, not between runs, which
		 * would re-initialise the chip and clear what we came to read.
		 */
		if (!strcmp(tok, "wait")) {
			/* A wait starts the next touch, so it ends a skip. */
			skipping = 0;
			printf("\n== wait %us -- touch the sensor now\n", arg);
			fflush(stdout);
			sleep(arg);
			continue;
		}

		/*
		 * "skipz:OFF" abandons the rest of this touch when the word at
		 * payload offset OFF of the previous command reads zero.
		 *
		 * CAPTURE_IMAGE reports at +0x20 whether it actually produced
		 * an image, and the vendor HAL tests exactly that before it
		 * goes on. Reporting a touch the application has no image for
		 * sends it into do_enroll, which dereferences a pointer a
		 * capture was supposed to have set -- and kills it.
		 */
		if (!strcmp(tok, "skipz")) {
			uint32_t word = 0;

			if (arg + 4 <= last_payload_len)
				memcpy(&word, last_payload + arg, 4);

			if (!word) {
				printf("\n== payload +0x%x is zero -- skipping "
				       "the rest of this touch\n", arg);
				fflush(stdout);
				skipping = 1;
			}
			continue;
		}

		if (skipping) {
			printf("   (skipped %s)\n", tok);
			continue;
		}

		cmd = strtoul(tok, NULL, 0);
		if (!cmd) {
			fprintf(stderr, "bad command '%s' in --seq\n", tok);
			free(copy);
			return -1;
		}

		printf("\n== 0x%04x%s\n", cmd, str ? " (own payload)" : "");
		last = invoke_full(fd, session, cmd, have, arg, FF_RSP_DEFAULT,
				   str ? str : req_str,
				   tnpk ? tpk : pokes, tnpk ? tnpk : npokes);

		/*
		 * -1 is the ioctl itself failing, which means the session is
		 * gone: the application has died and every command after this
		 * one answers "INVOKE: Invalid argument" too. Carrying on
		 * prints a screenful of identical failures and buries the one
		 * that mattered, so stop at the first. A refusal the
		 * application spells out (1) is not this -- those are often
		 * the expected answer -- and the sequence continues.
		 */
		if (last < 0) {
			fprintf(stderr,
				"0x%04x killed the session, stopping the "
				"sequence here\n", cmd);
			fflush(stdout);
			free(copy);
			return -1;
		}
	}

	free(copy);

	return last;
}

static void usage(void)
{
	fprintf(stderr,
		"usage: ftharness <version|load|probe|cmd ID> [options]\n"
		"  --app NAME   application to load (default " FF_APP_NAME ")\n"
		"  --arg N      32-bit argument, first word of the payload\n"
		"  --str S      send S as the payload, terminator included\n"
		"  --str-file F send F's contents as the payload\n"
		"  --req N      request region capacity (default %d)\n"
		"  --show-req N dump N bytes of the request payload after the\n"
		"               call -- where REPORT_EVENT leaves its answer\n"
		"  --rsp N      response region capacity (default %d)\n"
		"  --poke O=V   write word V at payload offset O (repeatable)\n"
		"  --seq LIST   run cmd[:arg][@file][+off=val],... in one\n"
		"               session; 'wait:N' pauses N seconds mid-session\n"
		"               and 'skipz:OFF' abandons the rest of a touch\n"
		"               when the last payload's word at OFF is zero\n"
		"               session, e.g. 0x100e+0=1,0x100a:1\n"
		"  (old form)   cmd[:arg][@file],... e.g.\n"
		"               0x1008:2000000,0x1011@cfg.json,0x100a:1\n"
		"  --reset      pulse the sensor's reset line first\n"
		"  --keep       hold the application loaded until enter\n",
		FF_REQ_DEFAULT, FF_RSP_DEFAULT);
}

int main(int argc, char **argv)
{
	const char *app = FF_APP_NAME;
	size_t rsp_size = FF_RSP_DEFAULT;
	uint32_t cmd_id = 0, arg_val = 0;
	int have_arg = 0, keep = 0, do_reset = 0;
	int priv_fd = -1, fd, session, ret;
	const char *mode;
	int i;

	/*
	 * Unbuffered, so the ordering on screen is the ordering that happened.
	 * stderr is unbuffered already, and with stdout block-buffered a failure
	 * printed before the output of the command that preceded it -- which
	 * reads as the wrong command having failed.
	 */
	setvbuf(stdout, NULL, _IONBF, 0);

	if (argc < 2) {
		usage();
		return 2;
	}

	mode = argv[1];

	for (i = 2; i < argc; i++) {
		if (!strcmp(argv[i], "--app") && i + 1 < argc)
			app = argv[++i];
		else if (!strcmp(argv[i], "--arg") && i + 1 < argc) {
			arg_val = strtoul(argv[++i], NULL, 0);
			have_arg = 1;
		} else if (!strcmp(argv[i], "--str") && i + 1 < argc)
			req_str = argv[++i];
		else if (!strcmp(argv[i], "--str-file") && i + 1 < argc) {
			req_str = slurp(argv[++i]);
			if (!req_str)
				return 1;
		}
		else if (!strcmp(argv[i], "--req") && i + 1 < argc)
			req_pad = strtoul(argv[++i], NULL, 0);
		else if (!strcmp(argv[i], "--show-req") && i + 1 < argc)
			req_show = strtoul(argv[++i], NULL, 0);
		else if (!strcmp(argv[i], "--rsp") && i + 1 < argc)
			rsp_size = strtoul(argv[++i], NULL, 0);
		else if (!strcmp(argv[i], "--poke") && i + 1 < argc) {
			char *eq;
			if (npokes == FF_MAX_POKE) {
				fprintf(stderr, "too many --poke\n");
				return 2;
			}
			pokes[npokes].off = strtoul(argv[++i], &eq, 0);
			if (*eq != '=') {
				fprintf(stderr, "--poke wants OFFSET=VALUE\n");
				return 2;
			}
			pokes[npokes].val = strtoul(eq + 1, NULL, 0);
			npokes++;
		} else if (!strcmp(argv[i], "--seq") && i + 1 < argc)
			seq_spec = argv[++i];
		else if (!strcmp(argv[i], "--reset"))
			do_reset = 1;
		else if (!strcmp(argv[i], "--keep"))
			keep = 1;
		else if (!strcmp(mode, "cmd") && cmd_id == 0)
			cmd_id = strtoul(argv[i], NULL, 0);
		else {
			usage();
			return 2;
		}
	}

	if (!strcmp(mode, "version"))
		return show_version() ? 1 : 0;

	if (!strcmp(mode, "cmd") && !cmd_id && !seq_spec) {
		fprintf(stderr, "cmd needs a command id, e.g. 0x100e\n");
		return 2;
	}

	if (seq_spec && strcmp(mode, "cmd") && strcmp(mode, "probe")) {
		fprintf(stderr, "--seq goes with cmd or probe\n");
		return 2;
	}

	if (strcmp(mode, "load") && strcmp(mode, "probe") && strcmp(mode, "cmd")) {
		usage();
		return 2;
	}

	if (do_reset && sensor_reset())
		return 1;

	if (load_app(app, &priv_fd))
		return 1;

	if (!strcmp(mode, "load")) {
		hold_loaded();
		close(priv_fd);
		return 0;
	}

	fd = open_client();
	if (fd < 0) {
		close(priv_fd);
		return 1;
	}

	session = open_session(fd, app);
	if (session < 0) {
		close(fd);
		close(priv_fd);
		return 1;
	}

	printf("session=%d on '%s'\n", session, app);

	if (seq_spec)
		ret = run_seq(fd, (uint32_t)session, seq_spec);
	else if (!strcmp(mode, "probe"))
		ret = probe(fd, (uint32_t)session);
	else
		ret = invoke(fd, (uint32_t)session, cmd_id, have_arg, arg_val,
			     rsp_size);

	if (keep) {
		printf("\n");
		hold_loaded();
	}

	close(fd);
	/* Closing the load session is what unloads the application. */
	close(priv_fd);

	return ret ? 1 : 0;
}
