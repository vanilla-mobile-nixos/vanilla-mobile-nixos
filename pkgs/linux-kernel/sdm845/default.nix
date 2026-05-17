# How to update:
# - Have a local copy of <https://gitlab.com/sdm845-mainline/linux.git>.
# - Vendor the patches using `./update-kernel-patches.sh`. Using Git forge
#   compare APIs aren't reliable for this.
# - Update the base NixOS kernel version that is being overridden.
# - Check for changes to `sdm845.config` and `misc.config`. Ex: `git diff sdm845-6.11 sdm845-6.14-rc5 -- arch/arm64/configs/sdm845.config`
# - Apply changes to `structuredExtraConfig` and `config_fixes.patch` as needed.
# - Check the config by disabling `ignoreConfigErrors = true` and building.
#   - If you the log shows a bunch of "Error in reading or end of file.", search it for
#     "repeated question". The repeated question error is usually due to NixOS setting
#     every module to `module`/`m` by default.
#     - If you set the option to `no`/`n`, look for a part of the error saying what it
#       was selected by. If any of those have `=y` or `=m`, you may need to set them
#       to `no` as well.
#     - If you set the option to `yes`/`y`, check the dependencies part of the error. If
#       any of the dependencies have `=m`, you may need to set them to `yes` as well.
#   - If you see a bunch of "unused option" errors, you can ignore those. Check
#     in-between them for more important errors. You can search "not set correctly"
#     to find most of those. Don't continue until confirming that there are no
#     unacceptable errors.
# - Re-enable `ignoreConfigErrors = true`.
# - Time to build! Good luck!!
{
  lib,
  linuxKernel,
  stdenv,
  ...
}:
let
  kernel = linuxKernel.kernels.linux_testing;
  version = "${kernel.version}-sdm845";
in
kernel.override {
  argsOverride = {
    inherit version;
    modDirVersion = kernel.modDirVersion;
  };
  kernelPatches = (import ./kernel-patches) ++ [
    {
      # Some sort of ordering issue with parts of structuredExtraConfig.
      # <https://git.pavluk.org/chayleaf/dotfiles/src/branch/master/system/hardware/oneplus-enchilada/config_fixes_611.patch>.
      name = "config-fixes";
      patch = ./config_fixes.patch;
    }
  ];

  # Remove some mostly raspberry pi specific stuff.
  # See <https://github.com/NixOS/nixpkgs/blob/master/lib/systems/platforms.nix>
  stdenv = lib.recursiveUpdate stdenv {
    hostPlatform.linux-kernel.extraConfig = "";
  };

  # To deal with all the unused option errors.
  ignoreConfigErrors = true;
  structuredExtraConfig = with lib.kernel; {
    # NixOS Unl0kr module wants these. They aren't actually needed for this device.
    I2C_DESIGNWARE_PLATFORM = module;
    TOUCHSCREEN_USB_COMPOSITE = module;

    # NixOS LUKS module expects these by default.
    # DM_CRYPT is definitely necessary.
    DM_CRYPT = module;
    CRYPTO_CRYPTD = module;
    CRYPTO_USER_API_SKCIPHER = module;
    CRYPTO_LRW = module;
    CRYPTO_BLOWFISH = module;
    CRYPTO_TWOFISH = module;
    CRYPTO_SERPENT = module;

    # fix build
    # I've confirmed the glink issue. Just went ahead and added the Lenovo, too.
    LENOVO_YOGA_C630_EC = no;
    RPMSG_QCOM_GLINK_SMEM = yes;

    # --- Start of sdm845.config ---

    # Needed everywhere
    GPIO_SHARED_PROXY = yes;

    # This introduces some weird race conditions. Stick to the
    # userspace one for now (6.13). still seem to happen in 7.1rc1.
    # makes mic not working in poco f1. no idea why.
    # See <https://gitlab.postmarketos.org/postmarketOS/pmaports/-/work_items/3481>.
    # I don't use the mic right now, so I'd rather not have to set
    # up the userspace pd_mmapper.
    # QCOM_PD_MAPPER = no;

    # OnePlus 6
    DRM_PANEL_SAMSUNG_SOFEF00 = yes;
    BATTERY_BQ27XXX = module;
    HID_RMI = module;
    RMI4_CORE = module;
    RMI4_I2C = module;
    RMI4_F55 = yes;
    VIDEO_IMX371 = module;
    VIDEO_IMX376 = module;
    VIDEO_IMX519 = module;
    VIDEO_LC898217XC = module;

    # OnePlus 6T
    DRM_PANEL_SAMSUNG_S6E3FC2X01 = yes;
    SND_SOC_TFA98XX = module;

    # Pocophone F1
    DRM_PANEL_NOVATEK_NT36672A = yes;
    DRM_PANEL_EBBG_FT8719 = yes;
    TOUCHSCREEN_NOVATEK_NVT_TS = module;
    SND_SOC_TAS2559 = module;
    VIDEO_IMX363 = module;
    VIDEO_BU64748 = module;

    # Samsung S9 SM-G9600(starqltechn)
    SND_SOC_MAX98512 = module;
    DRM_PANEL_SAMSUNG_S6E3HA8 = yes;
    TOUCHSCREEN_S6SY761 = module;
    MFD_SEC_CORE = yes;
    REGULATOR_S2DOS05 = module;
    MFD_MAX77705 = module;
    LEDS_MAX77705 = module;
    CHARGER_MAX77705 = module;
    INPUT_MAX77693_HAPTIC = module;
    PWM_CLK = module;

    # SHIFT6mq
    DRM_PANEL_VISIONOX_RM69299 = module;
    SND_SOC_TFA989X = module;
    VIDEO_DW9714 = module;

    # Pixel 3
    DRM_PANEL_LG_SW43408 = yes;
    TOUCHSCREEN_STMFTS = module;
    SND_SOC_CS35L36 = module;
    VIDEO_IMX355 = module;

    # Mi Mix 2S
    DRM_PANEL_NOVATEK_NT35596S = yes;

    # Mi Mix 3
    DRM_PANEL_SAMSUNG_EA8076 = yes;
    SND_SOC_TAS2557 = module;

    # C630
    DRM_TI_SN65DSI86 = yes;
    DRM_PANEL_EDP = yes;
    PHY_QCOM_EDP = yes;
    BACKLIGHT_PWM = yes;
    BATTERY_LENOVO_YOGA_C630 = module;

    # LG G7 ThinQ
    DRM_PANEL_LG_SW49410_LH609QH1 = yes;
    TOUCHSCREEN_SW49410 = yes;
    QCOM_WDT = yes;
    SPI_QCOM_GENI = yes;

    # SOC
    FORCE_NR_CPUS = yes;
    NR_CPUS = lib.mkForce (freeform "8");

    SCSI_UFS_QCOM = yes;
    RPMB = yes;

    QCOM_GSBI = yes;
    QCOM_LLCC = yes;
    QCOM_OCMEM = yes;
    QCOM_RMTFS_MEM = yes;
    QCOM_SOCINFO = yes;
    QCOM_WCNSS_CTRL = yes;
    QCOM_APR = yes;
    POWER_RESET_QCOM_PON = yes;
    QCOM_SPMI_TEMP_ALARM = yes;
    QCOM_LMH = yes;
    SCHED_CLUSTER = yes;
    SND_SOC_QDSP6_Q6VOICE = module;
    PHY_QCOM_QMP_PCIE = yes;
    BACKLIGHT_CLASS_DEVICE = yes;
    INTERCONNECT_QCOM_OSM_L3 = yes;
    I2C_QCOM_GENI = yes;

    # Remoteproc
    SLIMBUS = yes;
    REMOTEPROC_CDEV = yes;

    # Battery
    BATTERY_PMI8998_FG = module;
    CHARGER_QCOM_SMB2 = module;
    QCOM_SPMI_RRADC = module;

    # Graphics
    DRM = yes;
    FB_SIMPLE = yes;
    DRM_SIMPLEDRM = lib.mkForce no; # We're using `FB_SIMPLE`
    SYSFB_SIMPLEFB = lib.mkForce no; # We're using `FB_SIMPLE`
    DRM_MSM = yes;
    REGULATOR_QCOM_REFGEN = yes;

    # Brightness Control
    REGULATOR_QCOM_LABIBB = yes;
    BACKLIGHT_QCOM_WLED = yes;

    # Haptics
    INPUT_QCOM_SPMI_HAPTICS = module;

    # Needed for mounting userdata on android
    QFMT_V2 = yes;

    # USB
    PHY_QCOM_QMP_USB = yes;

    # Qcom stuff
    RPMSG_CHAR = yes;
    QCOM_SPMI_VADC = yes;
    QCOM_SPMI_ADC5 = yes;
    PHY_QCOM_QMP = yes;
    PHY_QCOM_QUSB2 = yes;
    PHY_QCOM_QMP_UFS = yes;
    PHY_QCOM_QMP_COMBO = yes;
    MFD_QCOM_RPM = yes;
    USB_DWC3_ULPI = yes;
    PHY_QCOM_USB_HS = yes;
    PHY_QCOM_USB_SNPS_FEMTO_V2 = yes;
    CRYPTO_DEV_QCE = yes;

    # Disable all unrelated stuffs afaik
    # When an option is separated by spaces, the options under the first one had
    # to be added, b/c of NixOS's autoModules where everything is set to `module` by
    # default.
    ARCH_BLAIZE = no;
    ARCH_SPARX5 = no;
    HIBERNATION = no;

    FW_LOADER_USER_HELPER = no;
    FW_LOADER_USER_HELPER_FALLBACK = no;
    LEDS_LP55XX_COMMON = no;
    LEDS_LP5521 = no;
    LEDS_LP5523 = no;
    LEDS_LP5562 = no;
    LEDS_LP5569 = no;
    LEDS_LP8501 = no;

    BLK_DEV_NVME = no;
    ATA = no;
    MTD = no;
    SRAM = no;
    MEGARAID_SAS = no;
    RAID6_PQ_BENCHMARK = no;
    EEPROM_AT25 = no;

    SCSI_MPT3SAS = no;
    SCSI_MPT2SAS = no;

    # BLK_DEV_MD = no;
    DM_MIRROR = no;
    DM_ZERO = no;
    EXT2_FS = no;
    EXT3_FS = no;
    USB_DWC2 = no;
    USB_CHIPIDEA = no;
    USB_MUSB_HDRC = no;
    USB_ISP1760 = no;
    USB_HSIC_USB3503 = no;
    USB_NET_PLUSB = no;
    TYPEC_FUSB302 = no;
    EXTCON_PTN5150 = no;
    NET_VENDOR_NI = no;
    NET_9P = no;
    CAN = no;
    BNX2X = no;
    MACB = no;
    IGB = no;
    IGBVF = no;
    SMC91X = no;
    MLX4_EN = no;
    MLX5_CORE = no;
    STMMAC_ETH = no;
    ATL1C = no;
    BRCMFMAC = no;

    WL18XX = no;
    WLCORE = no;
    WLCORE_SPI = no;
    WLCORE_SDIO = no;
    WL12XX = no;

    ATH10K_PCI = no;
    NET_SCH_CBS = no;
    NET_SCH_ETF = no;
    NET_SCH_TAPRIO = no;
    NET_SCH_MQPRIO = no;
    NET_CLS_BASIC = no;
    NET_CLS_FLOWER = no;
    # NET_CLS_ACT = no;
    NET_ACT_GACT = no;
    NET_ACT_MIRRED = no;
    NET_ACT_GATE = no;
    MDIO_BUS_MUX_MMIOREG = no;
    MDIO_BUS_MUX_MULTIPLEXER = no;
    SND_SOC_ES7134 = no;
    SND_SOC_ES7241 = no;
    SND_SOC_TAS571X = no;
    SND_SOC_SIMPLE_AMPLIFIER = no;
    GPIO_DWAPB = no;
    COMMON_CLK_XGENE = no;
    SENSORS_ARM_SCPI = no;
    TCG_TPM = no;
    BATTERY_SBS = no;
    REGULATOR_VCTRL = no;

    SND_SOC_MAX98357A = no;
    SND_SOC_STORM = no;
    SND_SOC_AMD_RV_RT5682_MACH = no;
    SND_SOC_MT8183_MT6358_TS3A227E_MAX98357A = no;
    SND_SOC_MT8183_DA7219_MAX98357A = no;
    SND_SOC_MT8186_MT6366 = no;
    SND_SOC_AMD_MACH_COMMON = no;
    SND_SOC_INTEL_AVS_MACH_MAX98357A = no;
    SND_SOC_INTEL_DA7219_MAX98357A_GENERIC = no;
    SND_SOC_INTEL_SOF_DA7219_MACH = no;
    SND_SOC_INTEL_SOF_RT5682_MACH = no;
    SND_SOC_INTEL_SOF_CS42L42_MACH = no;
    SND_SOC_INTEL_SOF_NAU8825_MACH = no;

    CAVIUM_ERRATUM_22375 = no;
    CAVIUM_ERRATUM_23154 = no;
    CAVIUM_ERRATUM_27456 = no;
    CAVIUM_ERRATUM_30115 = no;
    CAVIUM_TX2_ERRATUM_219 = no;
    HW_RANDOM_CAVIUM = no;
    NET_DSA = no;
    AQUANTIA_PHY = no;
    MICROSEMI_PHY = no;
    VITESSE_PHY = no;
    I2C_MUX_PCA954x = no;
    SND_SOC_PCM3168A_I2C = no;
    SENSORS_LM90 = no;
    SENSORS_INA2XX = no;
    RTC_DRV_DS3232 = no;
    SPI_NXP_FLEXSPI = no;
    GPIO_MAX732X = no;
    SENSORS_ISL29018 = no;
    MPL3115 = no;
    MFD_ROHM_BD718XX = no;
    ARM_SBSA_WATCHDOG = no;
    ARM_SMC_WATCHDOG = no;
    REGULATOR_PCA9450 = no;
    REGULATOR_PFUZE100 = no;
    DRM_PANEL_RAYDIUM_RM67191 = no;
    DRM_PANEL_SITRONIX_ST7703 = no;
    PHY_MIXEL_MIPI_DPHY = no;
    DRM_NWL_MIPI_DSI = no;
    DRM_MXSFB = no;
    SND_SOC_FSL_SAI = no;
    SND_SOC_FSL_ASRC = no;
    SND_SOC_FSL_MICFIL = no;
    SND_SOC_FSL_AUDMIX = no;
    SND_SOC_FSL_SPDIF = no;
    SND_SOC_WM8904 = no;
    RTC_DRV_RV8803 = no;
    RTC_DRV_DS1307 = no;
    RTC_DRV_PCF85363 = no;
    RTC_DRV_PCF2127 = no;
    PHY_FSL_IMX8MQ_USB = no;
    FUJITSU_ERRATUM_010001 = no;
    PCI_PASID = no;
    UACCE = no;
    SPI_CADENCE_QUADSPI = no;
    DW_WATCHDOG = no;
    NOP_USB_XCEIV = no;
    SURFACE_PLATFORMS = no;
    GPIO_PCA953X = no;
    BACKLIGHT_LP855X = no;
    MFD_MAX77620 = no;
    SENSORS_PWM_FAN = no;
    SENSORS_INA3221 = no;
    REGULATOR_MAX8973 = no;
    USB_CONN_GPIO = no;

    MICREL_PHY = no;
    KS8851 = no;
    KS8851_MLL = no;

    MFD_BD9571MWV = no;
    DRM_PANEL_LVDS = no;

    DRM_RCAR_LVDS = no;
    SND_SIMPLE_CARD_UTILS = no;
    SND_SOC_IMX_CARD = no;

    COMMON_CLK_VC5 = no;
    CRYPTO_DEV_CCREE = no;
    VIDEO_IMX219 = no;
    VIDEO_OV5645 = no;
    SND_SOC_AK4613 = no;
    SND_SIMPLE_CARD = no;
    SND_AUDIO_GRAPH_CARD = no;
    SND_AUDIO_GRAPH_CARD2 = no;
    TYPEC_HD3SS3220 = no;
    RTC_DRV_RX8581 = no;
    COMMON_CLK_CS2000_CP = no;
    KEYBOARD_ADC = no;
    REGULATOR_FAN53555 = no;
    TOUCHSCREEN_ATMEL_MXT = no;
    RTC_DRV_HYM8563 = no;
    PL330_DMA = no;
    GPIO_MB86S7X = no;
    MMC_SDHCI_F_SDH30 = no;
    MMC_SDHCI_CADENCE = no;
    SOCIONEXT_SYNQUACER_PREITS = no;
    NET_VENDOR_SOCIONEXT = no;
    ARCH_ACTIONS = no;
    ARCH_AGILEX = no;
    ARCH_N5X = no;
    ARCH_SUNXI = no;
    ARCH_ALPINE = no;
    ARCH_APPLE = no;
    ARCH_BCM2835 = no;
    ARCH_BCM4908 = no;
    ARCH_BCM_IPROC = no;
    ARCH_BERLIN = no;
    ARCH_BRCMSTB = no;
    ARCH_EXYNOS = no;
    ARCH_K3 = no;
    ARCH_LAYERSCAPE = no;
    ARCH_LG1K = no;
    ARCH_HISI = no;
    ARCH_KEEMBAY = no;
    ARCH_MEDIATEK = no;
    ARCH_MESON = no;
    ARCH_MVEBU = no;
    ARCH_MXC = no;
    ARCH_RENESAS = no;
    ARCH_ROCKCHIP = no;
    ARCH_S32 = no;
    ARCH_SEATTLE = no;
    ARCH_INTEL_SOCFPGA = no;
    ARCH_SYNQUACER = no;
    ARCH_TEGRA = no;
    ARCH_SPRD = no;
    ARCH_THUNDER = no;
    ARCH_THUNDER2 = no;
    ARCH_UNIPHIER = no;
    ARCH_VEXPRESS = no;
    ARCH_VISCONTI = no;
    ARCH_XGENE = no;
    ARCH_ZX = no;
    ARCH_ZYNQMP = no;
    ARM_ALLWINNER_SUN50I_CPUFREQ_NVMEM = no;
    ARM_ARMADA_37XX_CPUFREQ = no;
    ARM_IMX_CPUFREQ_DT = no;
    ARM_RASPBERRYPI_CPUFREQ = no;
    ARM_TEGRA186_CPUFREQ = no;
    QORIQ_CPUFREQ = no;
    RASPBERRYPI_FIRMWARE = no;
    INTEL_STRATIX10_SERVICE = no;
    INTEL_STRATIX10_RSU = no;
    IMX_SCU = no;
    IMX_SCU_PD = no;
    CAN_RCAR = no;
    CAN_RCAR_CANFD = no;
    CAN_FLEXCAN = no;
    PCI_AARDVARK = no;
    PCI_TEGRA = no;
    PCIE_RCAR_HOST = no;
    PCIE_RCAR_EP = no;
    PCI_XGENE = no;
    PCIE_ALTERA = no;
    PCIE_ALTERA_MSI = no;
    PCI_HOST_THUNDER_PEM = no;
    PCI_HOST_THUNDER_ECAM = no;
    PCIE_ROCKCHIP_HOST = no;
    PCIE_BRCMSTB = no;
    PCI_IMX6 = no;
    PCI_LAYERSCAPE = no;
    PCIE_LAYERSCAPE_GEN4 = no;
    PCI_HISI = no;
    PCIE_ARMADA_8K = no;
    PCIE_KIRIN = no;
    PCIE_HISI_STB = no;
    PCIE_TEGRA194_HOST = no;
    HISILICON_LPC = no;
    FSL_MC_BUS = no;
    TEGRA_ACONNECT = no;
    MTD_CFI_INTELEXT = no;
    MTD_CFI_AMDSTD = no;
    MTD_CFI_STAA = no;
    MTD_SST25L = no;
    MTD_NAND_DENALI_DT = no;
    MTD_NAND_MARVELL = no;
    MTD_NAND_FSL_IFC = no;
    SCSI_HISI_SAS = no;
    SCSI_HISI_SAS_PCI = no;
    SCSI_UFS_HISI = no;
    SCSI_UFS_EXYNOS = no;
    AHCI_CEVA = no;
    AHCI_MVEBU = no;
    AHCI_XGENE = no;
    AHCI_QORIQ = no;
    SATA_SIL24 = no;
    SATA_RCAR = no;
    FSL_FMAN = no;
    FSL_DPAA_ETH = no;
    FSL_DPAA2_ETH = no;
    FSL_ENETC = no;
    FSL_ENETC_VF = no;
    FSL_ENETC_QOS = no;
    HIX5HD2_GMAC = no;
    HNS_DSAF = no;
    HNS_ENET = no;
    HNS3 = no;
    HNS3_HCLGE = no;
    HNS3_ENET = no;
    SERIAL_MESON = no;
    SERIAL_MESON_CONSOLE = no;
    SERIAL_SAMSUNG = no;
    SERIAL_SAMSUNG_CONSOLE = no;
    SERIAL_TEGRA = no;
    SERIAL_TEGRA_TCU = no;
    SERIAL_IMX = no;
    SERIAL_IMX_CONSOLE = no;
    SERIAL_XILINX_PS_UART = no;
    SERIAL_XILINX_PS_UART_CONSOLE = no;
    SERIAL_FSL_LPUART = no;
    SERIAL_FSL_LPUART_CONSOLE = no;
    SERIAL_FSL_LINFLEXUART = no;
    SERIAL_FSL_LINFLEXUART_CONSOLE = no;
    SERIAL_MVEBU_UART = no;
    SERIAL_OWL = no;
    I2C_BCM2835 = no;
    # See reference later in file.
    # I2C_DESIGNWARE_PLATFORM = no;
    I2C_IMX = no;
    I2C_IMX_LPI2C = no;
    I2C_MESON = no;
    I2C_MT65XX = no;
    I2C_MV64XXX = no;
    I2C_OMAP = no;
    I2C_OWL = no;
    I2C_PXA = no;
    I2C_RK3X = no;
    I2C_SH_MOBILE = no;
    I2C_TEGRA = no;
    I2C_UNIPHIER_F = no;
    I2C_RCAR = no;
    SPI_ARMADA_3700 = no;
    SPI_BCM2835 = no;
    SPI_BCM2835AUX = no;
    SPI_DESIGNWARE = no;
    SPI_DW_DMA = no;
    SPI_DW_MMIO = no;
    SPI_FSL_LPSPI = no;
    SPI_FSL_QUADSPI = no;
    SPI_IMX = no;
    SPI_FSL_DSPI = no;
    SPI_MESON_SPICC = no;
    SPI_MESON_SPIFC = no;
    SPI_ORION = no;
    SPI_PL022 = no;
    SPI_ROCKCHIP = no;
    SPI_RPCIF = no;
    SPI_S3C64XX = no;
    SPI_SH_MSIOF = no;
    SPI_SUN6I = no;
    PINCTRL_MAX77620 = no;
    PINCTRL_OWL = no;
    PINCTRL_S700 = no;
    PINCTRL_S900 = no;
    PINCTRL_IMX8MM = no;
    PINCTRL_IMX8MN = no;
    PINCTRL_IMX8MP = no;
    PINCTRL_IMX8MQ = no;
    PINCTRL_IMX8QM = no;
    PINCTRL_IMX8QXP = no;
    PINCTRL_IMX8DXL = no;
    GPIO_ALTERA = no;
    GPIO_DAVINCI = no;
    GPIO_MPC8XXX = no;
    GPIO_MXC = no;
    GPIO_PL061 = no;
    GPIO_RCAR = no;
    GPIO_UNIPHIER = no;
    GPIO_VISCONTI = no;
    GPIO_XGENE = no;
    GPIO_XGENE_SB = no;
    GPIO_PCA953X_IRQ = no;
    GPIO_BD9571MWV = no;
    GPIO_MAX77620 = no;
    GPIO_SL28CPLD = no;
    ROCKCHIP_IODOMAIN = no;
    POWER_RESET_XGENE = no;
    POWER_RESET_SYSCON = no;
    GNSS_MTK_SERIAL = no;
    SENSORS_RASPBERRYPI_HWMON = no;
    SENSORS_SL28CPLD = no;
    QORIQ_THERMAL = no;
    SUN8I_THERMAL = no;
    IMX_SC_THERMAL = no;
    IMX8MM_THERMAL = no;
    ROCKCHIP_THERMAL = no;
    RCAR_THERMAL = no;
    RCAR_GEN3_THERMAL = no;
    ARMADA_THERMAL = no;
    BCM2711_THERMAL = no;
    BCM2835_THERMAL = no;
    BRCMSTB_THERMAL = no;
    EXYNOS_THERMAL = no;
    TEGRA_BPMP_THERMAL = no;
    TEGRA_SOCTHERM = no;
    UNIPHIER_THERMAL = no;
    SL28CPLD_WATCHDOG = no;
    ARM_SP805_WATCHDOG = no;
    S3C2410_WATCHDOG = no;
    SUNXI_WATCHDOG = no;
    IMX2_WDT = no;
    IMX_SC_WDT = no;
    MESON_GXBB_WATCHDOG = no;
    MESON_WATCHDOG = no;
    RENESAS_WDT = no;
    UNIPHIER_WATCHDOG = no;
    BCM2835_WDT = no;
    MFD_ALTERA_SYSMGR = no;
    MFD_AXP20X_I2C = no;
    MFD_AXP20X_RSB = no;
    MFD_EXYNOS_LPASS = no;
    MFD_HI6421_PMIC = no;
    MFD_HI655X_PMIC = no;
    MFD_MT6397 = no;
    MFD_RK808 = no;
    MFD_SL28CPLD = no;
    REGULATOR_AXP20X = no;
    REGULATOR_BD718XX = no;
    REGULATOR_BD9571MWV = no;
    REGULATOR_HI6421V530 = no;
    REGULATOR_HI655X = no;
    REGULATOR_MAX77620 = no;
    REGULATOR_MP8859 = no;
    REGULATOR_MT6358 = no;
    REGULATOR_MT6397 = no;
    REGULATOR_PF8X00 = no;
    REGULATOR_RK808 = no;
    REGULATOR_S2MPS11 = no;
    REGULATOR_TPS65132 = no;
    IR_MESON = no;
    IR_SUNXI = no;
    MEDIA_ANALOG_TV_SUPPORT = lib.mkForce no;
    MEDIA_DIGITAL_TV_SUPPORT = lib.mkForce no;
    MEDIA_SDR_SUPPORT = no;
    DRM_AMDGPU = no;
    VIDEO_RCAR_CSI2 = no;
    VIDEO_RCAR_VIN = no;
    VIDEO_SUN6I_CSI = no;
    VIDEO_SAMSUNG_S5P_JPEG = no;
    VIDEO_SAMSUNG_S5P_MFC = no;
    VIDEO_SAMSUNG_EXYNOS_GSC = no;
    VIDEO_RENESAS_FDP1 = no;
    VIDEO_RENESAS_FCP = no;
    VIDEO_RENESAS_VSP1 = no;
    SDR_PLATFORM_DRIVERS = no;
    VIDEO_RCAR_DRIF = no;
    DRM_I2C_NXP_TDA998X = no;
    DRM_MALI_DISPLAY = no;
    DRM_NOUVEAU = no;
    DRM_EXYNOS = no;
    DRM_EXYNOS5433_DECON = no;
    DRM_EXYNOS7_DECON = no;
    DRM_EXYNOS_DSI = no;
    DRM_EXYNOS_HDMI = no;
    DRM_EXYNOS_MIC = no;
    DRM_ROCKCHIP = no;
    ROCKCHIP_ANALOGIX_DP = no;
    ROCKCHIP_CDN_DP = no;
    ROCKCHIP_DW_HDMI = no;
    ROCKCHIP_DW_MIPI_DSI = no;
    ROCKCHIP_INNO_HDMI = no;
    ROCKCHIP_LVDS = no;
    DRM_RCAR_DU = no;
    DRM_RCAR_DW_HDMI = no;
    DRM_SUN4I = no;
    DRM_SUN6I_DSI = no;
    DRM_SUN8I_DW_HDMI = no;
    DRM_SUN8I_MIXER = no;
    DRM_TEGRA = no;
    DRM_PARADE_PS8640 = no;
    DRM_SII902X = no;
    DRM_THINE_THC63LVD1024 = no;
    DRM_VC4 = no;
    DRM_ETNAVIV = no;
    DRM_HISI_HIBMC = no;
    DRM_HISI_KIRIN = no;
    DRM_MEDIATEK = no;
    DRM_MEDIATEK_HDMI = no;
    DRM_MESON = no;
    DRM_PL111 = no;
    DRM_LIMA = no;
    DRM_PANFROST = no;
    SND_HDA_TEGRA = no;
    SND_HDA_CODEC_HDMI = no;
    SND_BCM2835_SOC_I2S = no;
    SND_SOC_FSL_EASRC = no;
    SND_IMX_SOC = no;
    SND_SOC_IMX_SGTL5000 = no;
    SND_SOC_IMX_SPDIF = no;
    SND_SOC_IMX_AUDMIX = no;
    SND_SOC_FSL_ASOC_CARD = no;
    SND_MESON_AXG_SOUND_CARD = no;
    SND_MESON_GX_SOUND_CARD = no;
    SND_SOC_ROCKCHIP = no;
    SND_SOC_ROCKCHIP_SPDIF = no;
    SND_SOC_ROCKCHIP_RT5645 = no;
    SND_SOC_RK3399_GRU_SOUND = no;
    SND_SOC_SAMSUNG = no;
    SND_SOC_RCAR = no;
    SND_SUN4I_I2S = no;
    SND_SUN4I_SPDIF = no;
    SND_SOC_TEGRA = no;
    SND_SOC_TEGRA210_AHUB = no;
    SND_SOC_TEGRA210_DMIC = no;
    SND_SOC_TEGRA210_I2S = no;
    SND_SOC_TEGRA186_DSPK = no;
    SND_SOC_TEGRA210_ADMAIF = no;
    SND_SOC_TEGRA_AUDIO_GRAPH_CARD = no;
    SND_SOC_GTM601 = no;
    SND_SOC_RT5659 = no;
    SND_SOC_WM8960 = no;
    SND_SOC_WM8962 = no;
    USB_XHCI_PCI_RENESAS = no;
    USB_XHCI_TEGRA = no;
    USB_EHCI_EXYNOS = no;
    USB_OHCI_EXYNOS = no;
    USB_RENESAS_USBHS_HCD = no;
    USB_RENESAS_USBHS = no;
    USB_CHIPIDEA_UDC = no;
    USB_CHIPIDEA_HOST = no;
    USB_RENESAS_USBHS_UDC = no;
    USB_RENESAS_USB3 = no;
    USB_TEGRA_XUDC = no;
    MMC_SDHCI_OF_ARASAN = no;
    MMC_SDHCI_OF_ESDHC = no;
    MMC_SDHCI_ESDHC_IMX = no;
    MMC_SDHCI_TEGRA = no;
    MMC_MESON_GX = no;
    MMC_DW_EXYNOS = no;
    MMC_DW_HI3798CV200 = no;
    MMC_DW_K3 = no;
    MMC_DW_ROCKCHIP = no;
    MMC_SUNXI = no;
    MMC_BCM2835 = no;
    MMC_MTK = no;
    MMC_SDHCI_XENON = no;
    MMC_SDHCI_AM654 = no;
    MMC_OWL = no;
    RTC_DRV_MAX77686 = no;
    RTC_DRV_RK808 = no;
    RTC_DRV_M41T80 = no;
    RTC_DRV_RV3028 = no;
    RTC_DRV_S5M = no;
    RTC_DRV_FSL_FTM_ALARM = no;
    RTC_DRV_S3C = no;
    RTC_DRV_PL031 = no;
    RTC_DRV_SUN6I = no;
    RTC_DRV_ARMADA38X = no;
    RTC_DRV_TEGRA = no;
    RTC_DRV_SNVS = no;
    RTC_DRV_IMX_SC = no;
    RTC_DRV_XGENE = no;
    DMA_BCM2835 = no;
    DMA_SUN6I = no;
    FSL_EDMA = no;
    IMX_SDMA = no;
    K3_DMA = no;
    MV_XOR = no;
    MV_XOR_V2 = no;
    OWL_DMA = no;
    TEGRA20_APB_DMA = no;
    TEGRA210_ADMA = no;
    RCAR_DMAC = no;
    RENESAS_USB_DMAC = no;
    TI_K3_UDMA = no;
    TI_K3_UDMA_GLUE_LAYER = no;
    COMMON_CLK_RK808 = no;
    COMMON_CLK_FSL_SAI = no;
    COMMON_CLK_S2MPS11 = no;
    COMMON_CLK_ZYNQMP = no;
    COMMON_CLK_BD718XX = no;
    CLK_RASPBERRYPI = no;
    CLK_IMX8MM = no;
    CLK_IMX8MN = no;
    CLK_IMX8MP = no;
    CLK_IMX8MQ = no;
    CLK_IMX8QXP = no;
    TI_SCI_CLK = no;
    IMX_MBOX = no;
    BCM2835_MBOX = no;
    ROCKCHIP_IOMMU = no;
    TEGRA_IOMMU_SMMU = no;
    MTK_IOMMU = no;
    OWL_PM_DOMAINS = no;
    RASPBERRYPI_POWER = no;
    FSL_DPAA = no;
    FSL_MC_DPIO = no;
    FSL_RCPM = no;
    MTK_PMIC_WRAP = no;
    ARCH_R8A774A1 = no;
    ARCH_R8A774B1 = no;
    ARCH_R8A774C0 = no;
    ARCH_R8A774E1 = no;
    ARCH_R8A77950 = no;
    ARCH_R8A77951 = no;
    ARCH_R8A77960 = no;
    ARCH_R8A77961 = no;
    ARCH_R8A77965 = no;
    ARCH_R8A77970 = no;
    ARCH_R8A77980 = no;
    ARCH_R8A77990 = no;
    ARCH_R8A77995 = no;
    ARCH_R8A779A0 = no;
    ARCH_R9A07G044 = no;
    ROCKCHIP_PM_DOMAINS = no;
    ARCH_TEGRA_132_SOC = no;
    ARCH_TEGRA_210_SOC = no;
    ARCH_TEGRA_186_SOC = no;
    ARCH_TEGRA_194_SOC = no;
    ARCH_TEGRA_234_SOC = no;
    TI_SCI_PM_DOMAINS = no;
    ARM_IMX_BUS_DEVFREQ = no;
    ARM_IMX8M_DDRC_DEVFREQ = no;
    RENESAS_RPCIF = no;
    EXYNOS_ADC = no;
    MAX9611 = no;
    ROCKCHIP_SARADC = no;
    PWM_BCM2835 = no;
    PWM_IMX27 = no;
    PWM_MESON = no;
    PWM_MTK_DISP = no;
    PWM_MEDIATEK = no;
    PWM_RCAR = no;
    PWM_ROCKCHIP = no;
    PWM_SAMSUNG = no;
    PWM_SL28CPLD = no;
    PWM_SUN4I = no;
    PWM_TEGRA = no;
    PWM_VISCONTI = no;
    SL28CPLD_INTC = no;
    RESET_IMX7 = no;
    RESET_TI_SCI = no;
    PHY_XGENE = no;
    PHY_SUN4I_USB = no;
    PHY_HI6220_USB = no;
    PHY_HISTB_COMBPHY = no;
    PHY_HISI_INNO_USB2 = no;
    PHY_MVEBU_CP110_COMPHY = no;
    PHY_MTK_TPHY = no;
    PHY_RCAR_GEN3_PCIE = no;
    PHY_RCAR_GEN3_USB2 = no;
    PHY_RCAR_GEN3_USB3 = no;
    PHY_ROCKCHIP_EMMC = no;
    PHY_ROCKCHIP_INNO_HDMI = no;
    PHY_ROCKCHIP_INNO_USB2 = no;
    PHY_ROCKCHIP_INNO_DSIDPHY = no;
    PHY_ROCKCHIP_PCIE = no;
    PHY_ROCKCHIP_TYPEC = no;
    PHY_SAMSUNG_UFS = no;
    PHY_UNIPHIER_USB2 = no;
    PHY_UNIPHIER_USB3 = no;
    PHY_TEGRA_XUSB = no;
    FSL_IMX8_DDR_PMU = no;
    HISI_PMU = no;
    NVMEM_IMX_OCOTP = no;
    NVMEM_IMX_OCOTP_SCU = no;
    MTK_EFUSE = no;
    ROCKCHIP_EFUSE = no;
    NVMEM_SUNXI_SID = no;
    UNIPHIER_EFUSE = no;
    MESON_EFUSE = no;
    NVMEM_RMEM = no;
    FPGA = no;
    FPGA_MGR_STRATIX10_SOC = no;
    FPGA_BRIDGE = no;
    ALTERA_FREEZE_BRIDGE = no;
    FPGA_REGION = no;
    OF_FPGA_REGION = no;
    INTERCONNECT_IMX = no;
    INTERCONNECT_IMX8MQ = no;
    INTERCONNECT_QCOM_MSM8996 = no;
    INTERCONNECT_QCOM_QCS404 = no;
    ARCH_BCMBCA = no;
    ARCH_NPCM = no;
    SERIAL_BCM63XX = no;
    PINCTRL_SC8280XP = no;
    BCM_SBA_RAID = no;
    DMA_ENGINE_RAID = no;
    SENSORS_GPIO_FAN = no;
    ARCH_BCM = no;
    ARCH_NXP = no;
    NET_VENDOR_ADI = no;
    PINCTRL_SC8180X = no;
    SND_SOC_SC7180 = no;
    SND_SOC_SC7280 = no;

    SND_SOC_ADAU7002 = no;
    SND_SOC_AMD_CZ_DA7219MX98357_MACH = no;
    SND_SOC_RT5682 = no;
    SND_SOC_RT5682_SDW = no;
    SND_SOC_ALL_CODECS = no;

    # --- End of sdm845.config ---

    # --- Start of misc.config ---

    # Bluetooth
    BT_BNEP = module;
    BT_BNEP_MC_FILTER = yes;
    BT_BNEP_PROTO_FILTER = yes;
    BT_LE = yes;
    BT_LE_L2CAP_ECRED = yes;
    BT_RFCOMM = module;
    BT_RFCOMM_TTY = yes;

    # Crypto
    CRYPTO_LZ4 = module;
    FS_ENCRYPTION = yes;
    FS_ENCRYPTION_INLINE_CRYPT = yes;
    CRYPTO_USER_API_AEAD = yes;

    # Networking
    # westwood is more efficient for wireless connections
    # than cubic
    DEFAULT_WESTWOOD = yes;
    NETLINK_DIAG = module;
    NET_SCH_HTB = module;
    NET_SCH_MULTIQ = module;
    NET_SCH_PRIO = module;
    PACKET_DIAG = yes;

    # DRM
    DRM_GUD = module;

    # Ramdisk
    BLK_DEV_RAM = module;
    BLK_DEV_RAM_COUNT = freeform "16";
    BLK_DEV_RAM_SIZE = freeform "8192";

    # EFI
    EFI_SBAT_FILE = freeform "";
    EFI_ZBOOT = yes;

    # UTF8
    FAT_DEFAULT_UTF8 = yes;

    # Inputs
    INPUT_JOYDEV = module;

    # Compression
    KERNEL_GZIP = yes;
    MODULE_COMPRESS = yes;
    MODULE_COMPRESS_ALL = yes;
    # NixOS sets it to XZ even though it uses ZSTD by default on modern kernels.
    MODULE_COMPRESS_XZ = lib.mkForce no;
    MODULE_COMPRESS_ZSTD = yes;
    MODULE_DECOMPRESS = yes;

    # Multi-Gen LRU
    LRU_GEN = yes;
    LRU_GEN_ENABLED = yes;
    LRU_GEN_WALKS_MMU = yes;

    # Native Language Support
    NLS_ASCII = yes;
    NLS_DEFAULT = freeform "utf8";
    NLS_UTF8 = module;

    # SCSI
    SCSI_SCAN_ASYNC = yes;

    # Sound
    SND_HWDEP = module;
    SND_USB_AUDIO_USE_MEDIA_CONTROLLER = yes;

    # TCP
    TCP_CONG_ADVANCED = yes;
    TCP_CONG_BIC = module;
    TCP_CONG_HTCP = module;
    TCP_CONG_WESTWOOD = yes;
    TYPEC = yes;

    # UNIX Sockets
    UNIX_DIAG = yes;

    # USB
    USB_CONFIGFS_F_HID = yes;
    USB_F_HID = module;

    # Serial
    U_SERIAL_CONSOLE = yes;

    # Pstore
    PSTORE = yes;
    PSTORE_CONSOLE = yes;
    PSTORE_PMSG = yes;
    PSTORE_RAM = yes;

    # Debugging
    ATH10K_DEBUG = yes;
    ATH10K_DEBUGFS = yes;
    ATH10K_SPECTRAL = yes;

    # ZRAM
    ZRAM_DEF_COMP = freeform "zstd";
    ZRAM_DEF_COMP_ZSTD = yes;

    # Misc useful things
    HZ_1000 = yes;

    # libcamera
    DMABUF_HEAPS_SYSTEM = yes;
    DMABUF_HEAPS_CMA = yes;
    DMABUF_HEAPS = yes;
    DMA_CMA = yes;
    CMA = yes;
    CMA_SIZE_MBYTES = lib.mkForce (freeform "256");

    # Debugging stuff
    STACKTRACE = yes;

    # Power management
    PM_AUTOSLEEP = yes;
    PM_WAKELOCKS = yes;

    # --- Enf of misc.config ---

    # These may have caused a comipation crash.
    TOUCHSCREEN_FTM4 = no;
    TOUCHSCREEN_STM_FTS_DOWNSTREAM = no;

    REALTEK_PHY = no;
    NET_DSA_REALTEK = no;
    HIBMCGE = no;
    R8169 = no;
  };
}
