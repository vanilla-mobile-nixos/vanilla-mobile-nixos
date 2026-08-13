// SPDX-License-Identifier: GPL-2.0-only
/*
 * Supplicant for the QSEECOM file service, so trusted applications can reach
 * their secure storage.
 *
 * A QSEE application that needs to read or write a secure object blocks until
 * the normal world answers. The focal32 fingerprint application does this for
 * everything it persists -- templates, calibration, its serial id -- and with
 * nothing serving the request, every one of those fails:
 *
 *   qsee_sfs_open('/data/vendor_de/0/fpdata/ft_fp_serial_id.bin', ..)
 *       = 'SFS_ERROR_GENERIC: Generic failure error'
 *
 * so nothing can be enrolled, and there is nothing to match against.
 *
 * The arrangement is OP-TEE's tee-supplicant, and the driver says so: a
 * supplicant declares a service by opening a session on the privileged device
 * with the listener id in parameter 0 and the shared buffer in parameter 1,
 * then loops on TEE_IOC_SUPPL_RECV and TEE_IOC_SUPPL_SEND. Requests and
 * replies pass through that one buffer.
 *
 * Listener 10 is "file system services", read out of the vendor's
 * /vendor/bin/qseecomd, where a table pairs each service name with its id
 * eight bytes later. RPMB (0x2000) and SSD (0x3000) in that same table match
 * the vendor kernel's own defines, which is what confirms the layout.
 *
 * Nothing here is trusted with anything: the application encrypts and
 * integrity-protects every object before it crosses this boundary, which is
 * exactly why the I/O can be handed to an ordinary process.
 *
 * Build: cc -O2 -o ffsupplicant ffsupplicant.c
 */

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <linux/bsg.h>
#include <linux/tee.h>

#ifndef SG_IO
#define SG_IO			0x2285
#endif

/* Mirrors enum qseecom_listener_status in the kernel's qcom_scm.h. */
#define QSEECOM_LISTENER_SUCCESS	0
#define QSEECOM_LISTENER_FAILURE	1

#define PRIV_DEV		"/dev/teepriv0"
#define TEE_IMPL_ID_QSEECOM	5

/*
 * "gpfile system services" in /vendor/bin/qseecomd's listener table, and the
 * one the fingerprint application's SFS calls actually reach. Listener 10,
 * "file system services", is a different service and never sees them.
 */
#define FS_LISTENER_ID		28672

/*
 * The vendor's implementation of this service is /vendor/lib64/libdrmfs.so.
 * Its dispatcher reads a 32-bit opcode from the head of the request, answers
 * opcode 12 immediately -- before it even checks that the partition is
 * mounted -- and routes 0..11 through a jump table to the real file
 * operations. Opcode 12 is a handshake: refuse it and the application gives up
 * before it ever sends a path.
 */
#define GPFS_OP_HELLO		12

/*
 * The GlobalPlatform file service's message, and the operation set behind it.
 * The layout and the `op % 4` dispatch are as implemented in the Goodix
 * fingerprint project's supplicant (GPL-2.0, sibling work on the same QSEE
 * plumbing), against the same Qualcomm service:
 *
 *	+0x000  u32  operation
 *	+0x004  path, 256 bytes
 *	+0x104  u32  offset, or the second path for a rename
 *	+0x108  u32  length
 *	+0x10c  u32  keep a backup, on write
 *	+0x110  data to write
 *
 * and the reply overwrites the head: operation, errno, byte count. A read puts
 * what it read at +12.
 *
 * The operation is taken modulo four, so the four verbs repeat across the
 * range: 0 read, 1 write, 2 remove, 3 rename.
 */
#define GP_NAME_OFF		0x004
#define GP_NAME_SIZE		256
#define GP_OFFSET_OFF		0x104
#define GP_LENGTH_OFF		0x108
#define GP_BACKUP_OFF		0x10c
#define GP_DATA_OFF		0x110
#define GP_REPLY_DATA_OFF	12
#define GP_READ_MAX		(500 * 1024)

#define GP_OP_READ		0
#define GP_OP_WRITE		1
#define GP_OP_REMOVE		2
#define GP_OP_RENAME		3

/*
 * Where the objects live. The application asks for Android paths --
 * /data/vendor_de/0/fpdata/... -- which mean nothing here, so everything is
 * rooted under one directory and the leading slash dropped. The contents are
 * sealed by the secure world before they arrive, so this is ciphertext.
 */
#define GP_STORE_DEFAULT	"/var/lib/ffsupplicant"

/*
 * RPMB, listener 0x2000, where the fingerprint application's storage actually
 * goes. librpmb.so's dispatcher switches on a 32-bit opcode at the head of the
 * request; these two reach rpmb_ufs_read() and rpmb_ufs_write().
 */
#define RPMB_OP_READ		0x102
#define RPMB_OP_WRITE		0x103

/* One RPMB data frame, as JEDEC defines it. */
#define RPMB_FRAME_SIZE		512

/*
 * The request and reply headers, from Qualcomm's own RPMB listener --
 * listeners/librpmbservice in qualcomm/minkipc, tz_rpmb_rw_req_t and
 * tz_rpmb_rw_res_t. The transport differs there (MinkIPC callback objects
 * rather than QSEECOM listeners) but the message is the same one.
 *
 *	request  { cmd_id, num_sectors, req_buff_len, req_buff_offset,
 *		   version, rel_wr_count }		24 bytes
 *	reply    { cmd_id, status, res_buff_len, res_buff_offset,
 *		   version }				20 bytes
 *
 * which is what the observed header decodes to exactly: `req_buff_offset` is
 * 0x18, the size of the request header, and the answer goes after the reply
 * header at 0x14. Note `req_buff_len` is one frame, not the buffer's size.
 */
struct rpmb_rw_req {
	uint32_t cmd_id;
	uint32_t num_sectors;
	uint32_t req_buff_len;
	uint32_t req_buff_offset;
	uint32_t version;
	uint32_t rel_wr_count;
} __attribute__((packed));

struct rpmb_rw_res {
	uint32_t cmd_id;
	int32_t  status;
	uint32_t res_buff_len;
	uint32_t res_buff_offset;
	uint32_t version;
} __attribute__((packed));

#define RPMB_ANSWER_OFF		(sizeof(struct rpmb_rw_res))

/*
 * Answer in the shape the secure world reads: it takes the outcome from
 * `status` and the byte count from `res_buff_len`, so leaving them as whatever
 * the buffer happened to hold reports success or failure at random.
 */
static void rpmb_reply(void *buf, int32_t status, uint32_t len)
{
	struct rpmb_rw_req req;
	struct rpmb_rw_res res = {};

	memcpy(&req, buf, sizeof(req));

	res.cmd_id = req.cmd_id;
	res.status = status;
	res.res_buff_len = len;
	res.res_buff_offset = RPMB_ANSWER_OFF;
	res.version = req.version;

	memcpy(buf, &res, sizeof(res));
}

static void note(const char *fmt, ...);

static const char *gp_store = GP_STORE_DEFAULT;

/*
 * Turn the application's absolute path into one under the store, refusing
 * anything that tries to climb out of it. The names are the application's own,
 * but they arrive over a boundary, so they get checked.
 */
static int gp_path(const void *buf, size_t off, char *out, size_t out_size)
{
	const char *name = (const char *)buf + off;
	size_t i;

	if (!memchr(name, 0, GP_NAME_SIZE))
		return -1;

	while (*name == '/')
		name++;

	if (!*name)
		return -1;

	for (i = 0; name[i]; i++) {
		if (name[i] == '.' && name[i + 1] == '.')
			return -1;
	}

	if ((size_t)snprintf(out, out_size, "%s/%s", gp_store, name) >= out_size)
		return -1;

	return 0;
}

/* Create the directories leading to a file, as the application expects. */
static int gp_mkparents(const char *path)
{
	char work[512];
	char *p;

	if ((size_t)snprintf(work, sizeof(work), "%s", path) >= sizeof(work))
		return -1;

	for (p = work + 1; *p; p++) {
		if (*p != '/')
			continue;
		*p = 0;
		if (mkdir(work, 0700) && errno != EEXIST)
			return -1;
		*p = '/';
	}

	return 0;
}

static void gp_reply(void *buf, uint32_t op, int error, uint32_t count)
{
	uint32_t v;

	v = op;      memcpy((char *)buf + 0, &v, 4);
	v = error;   memcpy((char *)buf + 4, &v, 4);
	v = count;   memcpy((char *)buf + 8, &v, 4);
}

/*
 * Serve one file request. Errors are reported as errno in the reply, which is
 * what the application reads -- answering a failure as success is what leaves
 * it believing it stored something it did not.
 */
static int gp_serve(void *buf, size_t size)
{
	char path[512], path2[512];
	uint32_t op, length = 0;
	int32_t offset = 0;
	int err = 0, fd;
	ssize_t n;

	if (size < GP_DATA_OFF)
		return -1;

	memcpy(&op, buf, sizeof(op));

	/*
	 * Opcode 12 is the handshake, and the vendor answers it with a plain
	 * "no such file" rather than success.
	 */
	if (op == GPFS_OP_HELLO) {
		gp_reply(buf, op, ENOENT, 0);
		return 0;
	}

	if (op > 12 || gp_path(buf, GP_NAME_OFF, path, sizeof(path))) {
		gp_reply(buf, op, EINVAL, 0);
		return 0;
	}

	if (op % 4 == GP_OP_READ || op % 4 == GP_OP_WRITE) {
		memcpy(&offset, (char *)buf + GP_OFFSET_OFF, 4);
		memcpy(&length, (char *)buf + GP_LENGTH_OFF, 4);

		if (offset < 0 || length > GP_READ_MAX ||
		    (op % 4 == GP_OP_WRITE && length > size - GP_DATA_OFF) ||
		    (op % 4 == GP_OP_READ && length > size - GP_REPLY_DATA_OFF)) {
			gp_reply(buf, op, EINVAL, 0);
			return 0;
		}
	}

	switch (op % 4) {
	case GP_OP_READ:
		fd = open(path, O_RDONLY | O_CLOEXEC);
		if (fd < 0) {
			err = errno;
			break;
		}
		n = pread(fd, (char *)buf + GP_REPLY_DATA_OFF, length, offset);
		if (n < 0)
			err = errno;
		else
			length = (uint32_t)n;
		close(fd);
		break;

	case GP_OP_WRITE:
		if (gp_mkparents(path)) {
			err = errno;
			break;
		}
		fd = open(path, O_WRONLY | O_CREAT | O_CLOEXEC, 0600);
		if (fd < 0) {
			err = errno;
			break;
		}
		n = pwrite(fd, (char *)buf + GP_DATA_OFF, length, offset);
		if (n != (ssize_t)length || fsync(fd))
			err = errno ? errno : EIO;
		close(fd);
		break;

	case GP_OP_REMOVE:
		if (unlink(path) && rmdir(path))
			err = errno;
		break;

	case GP_OP_RENAME:
		if (gp_path(buf, GP_OFFSET_OFF, path2, sizeof(path2)) ||
		    gp_mkparents(path2) || rename(path, path2))
			err = errno ? errno : EINVAL;
		break;
	}

	note("gpfs op %u (%s) '%s': %s, %u byte(s)\n", op,
	     op % 4 == GP_OP_READ ? "read" : op % 4 == GP_OP_WRITE ? "write" :
	     op % 4 == GP_OP_REMOVE ? "remove" : "rename",
	     path, err ? strerror(err) : "ok", err ? 0 : length);

	gp_reply(buf, op, err, err ? 0 : length);

	return 0;
}

/*
 * The RPMB well-known LUN. This is UFS, so there is no /dev/mmcblk0rpmb: the
 * LUN is 0xC144 -- UFS_UPIU_RPMB_WLUN (0xC4) through
 * ufshcd_upiu_wlun_to_scsi_wlun() -- with no block device, reachable through
 * bsg. CONFIG_CHR_DEV_SG is off on this kernel, so /dev/sg* does not exist.
 */
#define RPMB_BSG_DEV		"/dev/bsg/0:0:0:49476"

/*
 * How RPMB is addressed over UFS, per JEDEC: SECURITY PROTOCOL IN/OUT carrying
 * security protocol 0xEC, protocol-specific 0x0001. The secure world builds
 * and MACs the frames; this only carries them, which is the whole reason an
 * untrusted process may serve this listener.
 */
#define SCSI_SECURITY_PROTOCOL_IN	0xa2
#define SCSI_SECURITY_PROTOCOL_OUT	0xb5
#define SECURITY_PROTOCOL_UFS_RPMB	0xec

/* SCSI status: the device has sense data waiting. */
#define SCSI_CHECK_CONDITION		0x02

/*
 * The vendor answers it with the request buffer untouched: the store it makes
 * alongside goes to a stack scratch buffer, not the shared one, and the reply
 * is simply twelve bytes of whatever is already there. Copied rather than
 * invented -- mirroring libdrmfs.so is the only reason answering success here
 * is safe.
 */

/*
 * The vendor registers a 32 KiB buffer for this listener. The size is ours to
 * choose -- it is what TZ is told the buffer is -- but a request carrying a
 * path plus a block of file data needs room, and a short buffer would truncate
 * silently.
 */
#define SB_LEN			(32 * 1024)

/* Room for the handful of services a supplicant might offer at once. */
#define MAX_LISTENERS		64

static int verbose;

static void note(const char *fmt, ...)
{
	va_list ap;

	if (!verbose)
		return;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

static void dump(const void *p, size_t n, size_t max)
{
	const unsigned char *b = p;
	size_t i, j;

	if (n > max)
		n = max;

	for (i = 0; i < n; i += 16) {
		fprintf(stderr, "    %04zx  ", i);
		for (j = 0; j < 16 && i + j < n; j++)
			fprintf(stderr, "%02x ", b[i + j]);
		for (; j < 16; j++)
			fprintf(stderr, "   ");
		fprintf(stderr, " |");
		for (j = 0; j < 16 && i + j < n; j++)
			fprintf(stderr, "%c", (b[i + j] >= 0x20 &&
					       b[i + j] < 0x7f) ?
					      b[i + j] : '.');
		fprintf(stderr, "|\n");
	}
}

struct shm {
	int id;
	void *va;
	size_t size;
};

/*
 * An RPMB frame is self-describing, which is what lets a relay check its
 * reading of the request against the frame itself rather than trusting a
 * guess: the last two bytes are the request type, and the address, block
 * count and result sit just before them. All big-endian, unlike the request
 * header around them.
 */
static void describe_rpmb(const void *buf, size_t size)
{
	const unsigned char *b = buf;
	uint32_t arg1, framesz, off, arg2;
	const unsigned char *f;

	if (size < 0x18)
		return;

	memcpy(&arg1, b + 0x04, 4);
	memcpy(&framesz, b + 0x08, 4);
	memcpy(&off, b + 0x0c, 4);
	memcpy(&arg2, b + 0x14, 4);

	printf("    header: +4=%u  +8=%u  data_off=%u  +0x14=%u\n",
	       arg1, framesz, off, arg2);

	if (off + RPMB_FRAME_SIZE > size)
		return;

	/* JEDEC's tail: address at 504, block count at 506, result at 508. */
	f = b + off;
	printf("    frame:  req_type=%u addr=0x%04x blocks=%u result=%u\n",
	       (f[510] << 8) | f[511], (f[504] << 8) | f[505],
	       (f[506] << 8) | f[507], (f[508] << 8) | f[509]);
	printf("    frame tail: ");
	for (size_t i = 496; i < RPMB_FRAME_SIZE; i++)
		printf("%02x ", f[i]);
	printf("\n");
}

/*
 * One SECURITY PROTOCOL IN or OUT against the RPMB LUN. bsg speaks sg_io_v4,
 * not the older sg_io_hdr.
 */
static int rpmb_xfer_once(int fd, int out, void *buf, uint32_t len,
			  unsigned char *sense, size_t sense_len,
			  uint32_t *device_status)
{
	unsigned char cdb[12] = {};
	struct sg_io_v4 hdr = {};

	cdb[0] = out ? SCSI_SECURITY_PROTOCOL_OUT : SCSI_SECURITY_PROTOCOL_IN;
	cdb[1] = SECURITY_PROTOCOL_UFS_RPMB;
	cdb[2] = 0x00;
	cdb[3] = 0x01;
	/* Length in bytes, big-endian, with INC_512 left clear. */
	cdb[6] = (len >> 24) & 0xff;
	cdb[7] = (len >> 16) & 0xff;
	cdb[8] = (len >> 8) & 0xff;
	cdb[9] = len & 0xff;

	hdr.guard = 'Q';
	hdr.protocol = BSG_PROTOCOL_SCSI;
	hdr.subprotocol = BSG_SUB_PROTOCOL_SCSI_CMD;
	hdr.request_len = sizeof(cdb);
	hdr.request = (uintptr_t)cdb;
	hdr.max_response_len = sense_len;
	hdr.response = (uintptr_t)sense;
	hdr.timeout = 15000;

	if (out) {
		hdr.dout_xfer_len = len;
		hdr.dout_xferp = (uintptr_t)buf;
	} else {
		hdr.din_xfer_len = len;
		hdr.din_xferp = (uintptr_t)buf;
	}

	if (ioctl(fd, SG_IO, &hdr)) {
		fprintf(stderr, "RPMB %s %u bytes: %s\n",
			out ? "OUT" : "IN", len, strerror(errno));
		return -1;
	}

	*device_status = hdr.device_status;

	if (hdr.transport_status || hdr.driver_status) {
		fprintf(stderr, "RPMB %s: transport=0x%x driver=0x%x\n",
			out ? "OUT" : "IN", hdr.transport_status,
			hdr.driver_status);
		return -1;
	}

	return hdr.device_status ? -1 : 0;
}

/*
 * One SECURITY PROTOCOL IN or OUT against the RPMB LUN. bsg speaks sg_io_v4,
 * not the older sg_io_hdr.
 *
 * The first command after the device powers on answers CHECK CONDITION with a
 * UNIT ATTENTION, which is the device reporting that it reset rather than a
 * failure. Reporting it is what clears it, so the cure is to retry once. Left
 * unhandled it fails the secure world's first storage access of every session,
 * which looks exactly like storage being broken.
 */
static int rpmb_xfer(int fd, int out, void *buf, uint32_t len)
{
	unsigned char sense[32] = {};
	uint32_t device_status = 0;
	int ret;

	ret = rpmb_xfer_once(fd, out, buf, len, sense, sizeof(sense),
			     &device_status);
	if (!ret || device_status != SCSI_CHECK_CONDITION)
		return ret;

	/* Sense key is the low nibble of byte 2 in fixed-format sense data. */
	note("RPMB %s: check condition, sense key 0x%x -- retrying\n",
	     out ? "OUT" : "IN", sense[2] & 0x0f);

	memset(sense, 0, sizeof(sense));
	ret = rpmb_xfer_once(fd, out, buf, len, sense, sizeof(sense),
			     &device_status);
	if (ret)
		fprintf(stderr,
			"RPMB %s: still failing after retry, sense key 0x%x\n",
			out ? "OUT" : "IN", sense[2] & 0x0f);

	return ret;
}

/*
 * The device's verdict on the frames it was given. Response type and result
 * live in the frame's tail, big-endian: 0 means it accepted them.
 */
static void rpmb_report(const unsigned char *f, const char *what)
{
	unsigned int result = (f[508] << 8) | f[509];
	unsigned int type = (f[510] << 8) | f[511];
	unsigned int counter = ((unsigned int)f[500] << 24) | (f[501] << 16) |
			       (f[502] << 8) | f[503];

	if (result)
		fprintf(stderr, "RPMB %s: device refused, result=0x%04x "
			"(resp type %u, write counter %u)\n",
			what, result, type, counter);
	else
		note("RPMB %s: ok (resp type %u, write counter %u)\n",
		     what, type, counter);
}

/*
 * An authenticated data read: one request frame goes out, and the device
 * answers with as many frames as the request asked for. Both live at the
 * request's data offset, so the answer overwrites the question.
 */
static int rpmb_serve_read(int fd, void *buf, size_t size)
{
	uint32_t blocks, off;

	memcpy(&blocks, (char *)buf + 0x04, 4);
	memcpy(&off, (char *)buf + 0x0c, 4);

	if (!blocks || off > size ||
	    (size_t)blocks * RPMB_FRAME_SIZE > size - off ||
	    (size_t)blocks * RPMB_FRAME_SIZE > size - RPMB_ANSWER_OFF) {
		fprintf(stderr, "RPMB read: %u block(s) at offset %u will not "
			"fit a %zu byte buffer\n", blocks, off, size);
		return -1;
	}

	if (rpmb_xfer(fd, 1, (char *)buf + off, RPMB_FRAME_SIZE))
		return -1;

	/*
	 * The answer lands after the reply header, not at the request's own
	 * offset: Qualcomm's listener passes `rsp + sizeof(*rw_rsp)` as the
	 * destination and walks it independently of the request frames.
	 * Answering in place would put every frame four bytes from where the
	 * secure world reads it and run the last one past the end.
	 */
	if (rpmb_xfer(fd, 0, (char *)buf + RPMB_ANSWER_OFF,
		      blocks * RPMB_FRAME_SIZE)) {
		rpmb_reply(buf, -1, 0);
		return -1;
	}

	rpmb_reply(buf, 0, blocks * RPMB_FRAME_SIZE);

	/*
	 * What the device made of it. A non-zero result means the frames were
	 * refused -- a bad MAC, a stale write counter, an address out of range
	 * -- and handing that back as success is how the secure world ends up
	 * wedged, believing storage works when it does not.
	 */
	rpmb_report((const unsigned char *)buf + off, "read");

	return 0;
}

/*
 * An authenticated data write, as JEDEC lays it out: the frames go out, then a
 * result-read request, then the device's answer comes back. The secure world
 * MACs the write frames and checks the answer; the result-read request carries
 * no MAC, so building it here is not forging anything.
 */
static int rpmb_serve_write(int fd, void *buf, size_t size)
{
	unsigned char result_req[RPMB_FRAME_SIZE] = {};
	uint32_t blocks, off;

	memcpy(&blocks, (char *)buf + 0x04, 4);
	memcpy(&off, (char *)buf + 0x0c, 4);

	if (!blocks || off > size ||
	    (size_t)blocks * RPMB_FRAME_SIZE > size - off) {
		fprintf(stderr, "RPMB write: %u block(s) at offset %u will not "
			"fit a %zu byte buffer\n", blocks, off, size);
		return -1;
	}

	if (rpmb_xfer(fd, 1, (char *)buf + off, blocks * RPMB_FRAME_SIZE))
		return -1;

	/* RPMB_REQ_RESULT_READ, in the frame's last two bytes, big-endian. */
	result_req[RPMB_FRAME_SIZE - 1] = 5;

	if (rpmb_xfer(fd, 1, result_req, RPMB_FRAME_SIZE))
		return -1;

	/*
	 * The answer replaces the request in the buffer: one frame, carrying
	 * the result code and the incremented write counter that the secure
	 * world checks against what it sent.
	 */
	/* The result frame is the answer, so it lands after the reply header. */
	if (rpmb_xfer(fd, 0, (char *)buf + RPMB_ANSWER_OFF, RPMB_FRAME_SIZE)) {
		rpmb_reply(buf, -1, 0);
		return -1;
	}

	rpmb_report((const unsigned char *)buf + RPMB_ANSWER_OFF, "write");
	rpmb_reply(buf, 0, RPMB_FRAME_SIZE);

	return 0;
}

/* One service offered: its id, the buffer its requests arrive in, and the
 * session that withdraws it. */
struct service {
	uint32_t id;
	struct shm sb;
	uint32_t session;
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
 * The privileged device is the one that registers listeners; the client device
 * cannot. Which /dev/teeN belongs to this driver depends on what else probed
 * first, so ask rather than assume -- but only the privileged node will do.
 */
static int open_priv(void)
{
	struct tee_ioctl_version_data vers;
	int fd = open(PRIV_DEV, O_RDWR);

	if (fd < 0) {
		fprintf(stderr, "%s: %s\n", PRIV_DEV, strerror(errno));
		return -1;
	}

	if (ioctl(fd, TEE_IOC_VERSION, &vers) ||
	    vers.impl_id != TEE_IMPL_ID_QSEECOM) {
		fprintf(stderr, "%s is not the QSEECOM driver\n", PRIV_DEV);
		close(fd);
		return -1;
	}

	return fd;
}

/*
 * Register the service. A null UUID plus {value, memref} is how the driver
 * tells a listener registration from an application load, and the session it
 * hands back is what withdraws the service when closed.
 */
static int register_listener(int fd, uint32_t id, struct shm *sb,
			     uint32_t *session)
{
	struct {
		struct tee_ioctl_open_session_arg arg;
		struct tee_ioctl_param params[2];
	} buf = {};
	struct tee_ioctl_buf_data bd;

	buf.arg.num_params = 2;
	buf.arg.clnt_login = TEE_IOCTL_LOGIN_PUBLIC;

	buf.params[0].attr = TEE_IOCTL_PARAM_ATTR_TYPE_VALUE_INPUT;
	buf.params[0].a = id;

	buf.params[1].attr = TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_INOUT;
	buf.params[1].b = sb->size;
	buf.params[1].c = sb->id;

	bd.buf_ptr = (uintptr_t)&buf;
	bd.buf_len = sizeof(buf);

	if (ioctl(fd, TEE_IOC_OPEN_SESSION, &bd)) {
		fprintf(stderr, "OPEN_SESSION(listener %u): %s\n", id,
			strerror(errno));
		return -1;
	}

	if (buf.arg.ret) {
		fprintf(stderr, "listener %u refused: ret=0x%x origin=0x%x\n",
			id, buf.arg.ret, buf.arg.ret_origin);
		return -1;
	}

	*session = buf.arg.session;

	return 0;
}

static void close_session(int fd, uint32_t session)
{
	struct tee_ioctl_close_session_arg arg = { .session = session };

	if (ioctl(fd, TEE_IOC_CLOSE_SESSION, &arg))
		fprintf(stderr, "CLOSE_SESSION: %s\n", strerror(errno));
}

static int rpmb_fd = -1;

static volatile sig_atomic_t stop;

static void on_signal(int sig)
{
	(void)sig;
	stop = 1;
}

int main(int argc, char **argv)
{
	struct service svc[MAX_LISTENERS] = {};
	const char *rpmb_dev = RPMB_BSG_DEV;
	unsigned int nsvc = 0;
	int fd, i;
	unsigned long served = 0;

	for (i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-v"))
			verbose = 1;
		else if (!strcmp(argv[i], "--store") && i + 1 < argc)
			gp_store = argv[++i];
		else if (!strcmp(argv[i], "--listener") && i + 1 < argc) {
			if (nsvc == MAX_LISTENERS) {
				fprintf(stderr, "at most %d listeners\n",
					MAX_LISTENERS);
				return 2;
			}
			svc[nsvc++].id = strtoul(argv[++i], NULL, 0);
		} else if (!strcmp(argv[i], "--rpmb-dev") && i + 1 < argc) {
			rpmb_dev = argv[++i];
		} else if (!strcmp(argv[i], "--range") && i + 1 < argc) {
			/*
			 * Offer every id in a range, to find which service a
			 * secure-world caller actually reaches. Registration
			 * of an id already taken fails, so this skips those
			 * rather than giving up.
			 */
			unsigned long lo, hi;
			char *dash;

			lo = strtoul(argv[++i], &dash, 0);
			hi = (dash && *dash == '-') ? strtoul(dash + 1, NULL, 0)
						    : lo;
			for (; lo <= hi && nsvc < MAX_LISTENERS; lo++)
				svc[nsvc++].id = lo;
		} else {
			fprintf(stderr,
				"usage: ffsupplicant [-v] [--listener N]...\n"
				"                    [--range A-B]...\n"
				"  -v            dump every request and reply\n"
				"  --listener N  service to offer, repeatable\n"
				"                (default %u, \"gpfile system\n"
				"                services\")\n"
				"  --range A-B   offer every id in a range, to\n"
				"                find which service a caller\n"
				"                actually reaches; ids that do\n"
				"                not register are skipped\n"
				"\n"
				"Only one process can receive: the driver hands\n"
				"requests to whichever context asks first, so a\n"
				"supplicant must offer every service it serves\n"
				"itself rather than running one per listener.\n"
				"\n"
				"TrustZone also caps how many listeners exist at\n"
				"once -- around two dozen -- so a wide --range\n"
				"can crowd out the ids that matter and look like\n"
				"a service that never fires. Offer few.\n",
				FS_LISTENER_ID);
			return 2;
		}
	}

	if (!nsvc)
		svc[nsvc++].id = FS_LISTENER_ID;

	/*
	 * sigaction without SA_RESTART, not signal(): glibc's signal() restarts
	 * an interrupted system call, so the handler would run, set the flag,
	 * and the blocking SUPPL_RECV would resume as if nothing had happened.
	 * The loop never got to look at the flag, every stop took the ninety
	 * seconds systemd waits before SIGKILL, and a service left dead that
	 * way is indistinguishable -- to anything but the journal -- from one
	 * that is running but answering nothing.
	 */
	{
		struct sigaction sa = { .sa_handler = on_signal };

		sigemptyset(&sa.sa_mask);
		sigaction(SIGINT, &sa, NULL);
		sigaction(SIGTERM, &sa, NULL);
	}

	fd = open_priv();
	if (fd < 0)
		return 1;

	for (i = 0; i < (int)nsvc; i++) {
		if (shm_alloc(fd, SB_LEN, &svc[i].sb)) {
			close(fd);
			return 1;
		}

		if (register_listener(fd, svc[i].id, &svc[i].sb,
				      &svc[i].session)) {
			/*
			 * An id already registered, or one TZ will not hand
			 * out, is not fatal when sweeping a range: drop it and
			 * keep the rest.
			 */
			svc[i].id = 0;
			continue;
		}

		printf("listener %u registered, buffer %zu bytes\n",
		       svc[i].id, svc[i].sb.size);
	}

	rpmb_fd = open(rpmb_dev, O_RDWR);
	if (rpmb_fd < 0)
		fprintf(stderr, "%s: %s -- RPMB requests will be refused\n",
			rpmb_dev, strerror(errno));
	else
		printf("RPMB LUN %s opened\n", rpmb_dev);

	printf("waiting for requests\n");
	fflush(stdout);

	while (!stop) {
		struct {
			struct tee_iocl_supp_recv_arg arg;
			struct tee_ioctl_param params[2];
		} rx = {};
		struct {
			struct tee_iocl_supp_send_arg arg;
			struct tee_ioctl_param params[2];
		} tx = {};
		struct tee_ioctl_buf_data bd;
		struct service *cur;
		uint32_t gen;

		rx.arg.num_params = 2;
		bd.buf_ptr = (uintptr_t)&rx;
		bd.buf_len = sizeof(rx);

		if (ioctl(fd, TEE_IOC_SUPPL_RECV, &bd)) {
			if (errno == EINTR)
				continue;
			fprintf(stderr, "SUPPL_RECV: %s\n", strerror(errno));
			break;
		}

		/*
		 * param[0] carries the generation this request was handed out
		 * with, and the answer has to echo it back: a supplicant that
		 * overran the timeout would otherwise apply its answer to
		 * whatever request took the slot in the meantime.
		 */
		gen = rx.params[0].a;

		/*
		 * Which service the request is for. The buffer it arrives in
		 * is that listener's own, so the id is how a supplicant
		 * offering several of them knows where to look.
		 */
		cur = NULL;
		for (i = 0; i < (int)nsvc; i++)
			if (svc[i].id == rx.arg.func)
				cur = &svc[i];

		served++;
		{
			uint32_t op = 0;

			if (cur && cur->sb.size >= 4)
				memcpy(&op, cur->sb.va, sizeof(op));

			printf("\n=== request %lu on listener %u, opcode %u "
			       "(generation %u)\n",
			       served, rx.arg.func, op, gen);

			if (cur && (op == RPMB_OP_READ || op == RPMB_OP_WRITE))
				describe_rpmb(cur->sb.va, cur->sb.size);
		}
		if (cur)
			dump(cur->sb.va, cur->sb.size, 256);
		else
			printf("    (no buffer for listener %u?)\n",
			       rx.arg.func);
		fflush(stdout);

		/*
		 * Anything not understood is refused rather than answered
		 * with a claim of success: the application would go on
		 * believing it had read or written its object, and a bogus
		 * success is what wedges the secure world.
		 */
		tx.arg.ret = QSEECOM_LISTENER_FAILURE;

		if (cur && cur->sb.size >= 12) {
			uint32_t op;

			memcpy(&op, cur->sb.va, sizeof(op));

			if (cur->id == FS_LISTENER_ID) {
				if (!gp_serve(cur->sb.va, cur->sb.size))
					tx.arg.ret = QSEECOM_LISTENER_SUCCESS;
			} else if ((op == RPMB_OP_READ || op == RPMB_OP_WRITE) &&
				   rpmb_fd >= 0) {
				uint32_t status = 0;
				int bad;

				bad = (op == RPMB_OP_READ) ?
				      rpmb_serve_read(rpmb_fd, cur->sb.va,
						      cur->sb.size) :
				      rpmb_serve_write(rpmb_fd, cur->sb.va,
						       cur->sb.size);

				if (bad) {
					status = (uint32_t)-1;
				} else {
					tx.arg.ret = QSEECOM_LISTENER_SUCCESS;
					note("opcode %u: %s served\n", op,
					     op == RPMB_OP_READ ? "read" :
								  "write");
				}

				/*
				 * The dispatcher's own error path writes its
				 * return code here, so this is where the
				 * secure world looks for one.
				 */
				memcpy((char *)cur->sb.va + 4, &status, 4);
			} else {
				note("opcode %u: not implemented, refusing\n",
				     op);
			}
		}
		tx.arg.num_params = 2;
		tx.params[0].attr = TEE_IOCTL_PARAM_ATTR_TYPE_VALUE_OUTPUT;
		tx.params[0].a = gen;
		tx.params[1].attr = TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_INOUT;
		tx.params[1].b = cur ? cur->sb.size : 0;
		tx.params[1].c = cur ? cur->sb.id : 0;

		bd.buf_ptr = (uintptr_t)&tx;
		bd.buf_len = sizeof(tx);

		if (ioctl(fd, TEE_IOC_SUPPL_SEND, &bd)) {
			fprintf(stderr, "SUPPL_SEND: %s\n", strerror(errno));
			break;
		}

		note("answered request %lu\n", served);
	}

	printf("\nserved %lu request(s), withdrawing\n", served);
	for (i = 0; i < (int)nsvc; i++)
		close_session(fd, svc[i].session);
	close(fd);

	return 0;
}
