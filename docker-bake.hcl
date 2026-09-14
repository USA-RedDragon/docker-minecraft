variable "REGISTRY" {
  default = "ghcr.io/usa-reddragon"
}

variable "JAVA_17_IMAGE" {
  default = "amazoncorretto:17.0.20-alpine@sha256:8aa46a55845b61ba079f8289556fcc1a7887cdf303d360bc27140ab38300d44e"
}

variable "JAVA_25_IMAGE" {
  default = "amazoncorretto:25.0.4-alpine@sha256:2ad5f5cf03a3970f2478b130dc28f51b179ce13c58154fe3ec1a6fdeb3b86e3a"
}

# The Fabric loader and installer are not tied to a Minecraft version
variable "FABRIC_LOADER_VERSION" {
  default = "0.19.5"
}

variable "FABRIC_INSTALLER_VERSION" {
  default = "1.1.2"
}

# Minecraft 1.19.2 - 1.20.2 are held on the 0.11 installer
variable "FABRIC_LEGACY_INSTALLER_VERSION" {
  default = "0.11.2"
}

group "default" {
  targets = ["paper", "fabric", "forge", "neoforge"]
}

function "target_suffix" {
  params = [mc]
  result = replace(mc, ".", "_")
}

target "_common" {
  context    = "."
  dockerfile = "Dockerfile"
}

# Entries without `java` use the Dockerfile's default Java image
target "paper" {
  inherits = ["_common"]
  name     = "paper-${target_suffix(v.mc)}"
  matrix = {
    v = [
      { mc = "26.2", build = "123", java = JAVA_25_IMAGE, latest = true },
      { mc = "26.1.2", build = "74", java = JAVA_25_IMAGE },
      { mc = "1.21.11", build = "132" },
      { mc = "1.21.10", build = "130" },
      { mc = "1.21.8", build = "60" },
      { mc = "1.21.7", build = "32" },
      { mc = "1.21.6", build = "48" },
      { mc = "1.21.4", build = "232" },
      { mc = "1.21.3", build = "83" },
      { mc = "1.21.1", build = "133" },
      { mc = "1.21", build = "130" },
      { mc = "1.20.6", build = "151" },
      { mc = "1.20.4", build = "499" },
      { mc = "1.20.2", build = "318" },
      { mc = "1.20.1", build = "196" },
    ]
  }
  target = "paper"
  args = {
    JAVA_IMAGE    = try(v.java, null)
    PAPER_VERSION = v.mc
    PAPER_BUILD   = v.build
  }
  tags = concat(
    ["${REGISTRY}/papermc:${v.mc}", "${REGISTRY}/papermc:${v.mc}-${v.build}"],
    try(v.latest, false) ? ["${REGISTRY}/papermc:latest"] : [],
  )
}

target "fabric" {
  inherits = ["_common"]
  name     = "fabric-${target_suffix(v.mc)}"
  matrix = {
    v = [
      { mc = "26.2", java = JAVA_25_IMAGE, latest = true },
      { mc = "26.1.2", java = JAVA_25_IMAGE },
      { mc = "26.1.1", java = JAVA_25_IMAGE },
      { mc = "26.1", java = JAVA_25_IMAGE },
      { mc = "1.21.11" },
      { mc = "1.21.10" },
      { mc = "1.21.9" },
      { mc = "1.21.8" },
      { mc = "1.21.7" },
      { mc = "1.21.6" },
      { mc = "1.21.5" },
      { mc = "1.21.4" },
      { mc = "1.21.3" },
      { mc = "1.21.2" },
      { mc = "1.21.1" },
      { mc = "1.21" },
      { mc = "1.20.6" },
      { mc = "1.20.5" },
      { mc = "1.20.4" },
      { mc = "1.20.3" },
      { mc = "1.20.2", installer = FABRIC_LEGACY_INSTALLER_VERSION },
      { mc = "1.20.1", installer = FABRIC_LEGACY_INSTALLER_VERSION },
      { mc = "1.19.2", installer = FABRIC_LEGACY_INSTALLER_VERSION },
    ]
  }
  target = "fabric"
  args = {
    JAVA_IMAGE        = try(v.java, null)
    MC_VERSION        = v.mc
    FABRIC_VERSION    = FABRIC_LOADER_VERSION
    INSTALLER_VERSION = try(v.installer, FABRIC_INSTALLER_VERSION)
  }
  tags = concat(
    ["${REGISTRY}/fabric:${v.mc}"],
    try(v.latest, false) ? ["${REGISTRY}/fabric:latest"] : [],
  )
}

# Only Minecraft versions with a recommended Forge release
target "forge" {
  inherits = ["_common"]
  # Forge versions are prefixed with the Minecraft version, e.g. "1.20.1-47.4.23"
  name = "forge-${target_suffix(split("-", v.forge)[0])}"
  matrix = {
    v = [
      { forge = "26.2-65.1.0", java = JAVA_25_IMAGE, latest = true },
      { forge = "26.1.2-64.1.0", java = JAVA_25_IMAGE },
      { forge = "1.21.11-61.2.0" },
      { forge = "1.21.10-60.1.0" },
      { forge = "1.21.8-58.1.0" },
      { forge = "1.21.5-55.1.0" },
      { forge = "1.21.4-54.1.14" },
      { forge = "1.21.3-53.1.0" },
      { forge = "1.21.1-52.1.0" },
      { forge = "1.20.6-50.2.0" },
      { forge = "1.20.1-47.4.23", java = JAVA_17_IMAGE },
    ]
  }
  target = "forge"
  args = {
    JAVA_IMAGE    = try(v.java, null)
    FORGE_VERSION = v.forge
  }
  tags = concat(
    ["${REGISTRY}/forge:${split("-", v.forge)[0]}", "${REGISTRY}/forge:${v.forge}"],
    try(v.latest, false) ? ["${REGISTRY}/forge:latest"] : [],
  )
}

target "neoforge" {
  inherits = ["_common"]
  name     = "neoforge-${target_suffix(v.mc)}"
  matrix = {
    v = [
      { mc = "26.2", neoforge = "26.2.0.88", java = JAVA_25_IMAGE, latest = true },
      { mc = "26.1.2", neoforge = "26.1.2.109", java = JAVA_25_IMAGE },
      { mc = "1.21.11", neoforge = "21.11.45" },
      { mc = "1.21.10", neoforge = "21.10.64" },
      { mc = "1.21.8", neoforge = "21.8.54" },
      { mc = "1.21.5", neoforge = "21.5.98" },
      { mc = "1.21.4", neoforge = "21.4.157" },
      { mc = "1.21.3", neoforge = "21.3.97" },
      { mc = "1.21.1", neoforge = "21.1.250" },
      { mc = "1.21", neoforge = "21.0.167" },
      { mc = "1.20.6", neoforge = "20.6.141" },
      { mc = "1.20.4", neoforge = "20.4.251", java = JAVA_17_IMAGE },
      { mc = "1.20.2", neoforge = "20.2.93", java = JAVA_17_IMAGE },
    ]
  }
  target = "neoforge"
  args = {
    JAVA_IMAGE       = try(v.java, null)
    NEOFORGE_VERSION = v.neoforge
  }
  tags = concat(
    ["${REGISTRY}/neoforge:${v.mc}", "${REGISTRY}/neoforge:${v.neoforge}"],
    try(v.latest, false) ? ["${REGISTRY}/neoforge:latest"] : [],
  )
}
