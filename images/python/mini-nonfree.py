from drakx.isoimage import IsoImage
from drakx.releaseconfig import ReleaseConfig
from drakx.media import Media
from drakx.distribution import Distribution
import os

config = ReleaseConfig("2013.0", "Oxygen", "EE", subversion="Alpha", medium="CD")
os.system("rm -rf "+config.outdir)

srcdir = "./"
rpmsrate = "../../perl-install/install/share/meta-task/rpmsrate-raw"
compssusers = "../../perl-install/install/share/meta-task/compssUsers.pl"
filedeps = srcdir + "file-deps"


media = []
for m in "main", "contrib", "non-free":
    media.append(Media(m))

includelist = []
for l in ["basesystem_mini", "languages", "firmware_nonfree"]:
    includelist.append(srcdir + "lists/" + l)

includelist32 = includelist + [srcdir + "lists/" + "kernel32"]
includelist64 = includelist + [srcdir + "lists/" + "kernel64_mini"]

excludelist = []
for e in ["exclude", "exclude_mini", "exclude_ancient", "exclude_tofix", "exclude_nonfree"]:
    excludelist.append(srcdir + "lists/" + e)

x86_64 = Distribution(config, "x86_64", media, includelist64, excludelist, rpmsrate, compssusers, filedeps, synthfilter=".xz:xz --text")
i586 = Distribution(config, "i586", media, includelist32, excludelist, rpmsrate, compssusers, filedeps, synthfilter=".xz:xz --text", stage2="../mdkinst-i586.cpio.xz")

distrib=[i586,x86_64]

image = IsoImage(config, distrib, maxsize=700)
