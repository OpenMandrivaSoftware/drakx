from drakx.isoimage import IsoImage
from drakx.releaseconfig import ReleaseConfig
from drakx.media import Media
from drakx.distribution import Distribution
import os

config = ReleaseConfig("2013.0", "Oxygen", "Free", subversion="Alpha", medium="DVD")
os.system("rm -rf "+config.outdir)

srcdir = "./"
rpmsrate = "../../perl-install/install/share/meta-task/rpmsrate-raw"
compssusers = "../../perl-install/install/share/meta-task/compssUsers.pl"
filedeps = srcdir + "file-deps"

media = []
for m in "main", "contrib":
    media.append(Media(m))

srcdir = "./"
includelist = []
for l in ["basesystem_mini", "input_cat", "theme-omv", "kernel64", "languages", "input_contrib"]:
    includelist.append(srcdir + "lists/" + l)
excludelist = []
for e in ["exclude", "exclude_free", "exclude_ancient", "exclude_tofix", "exclude_nonfree", "exclude_contrib64"]:
    excludelist.append(srcdir + "lists/" + e)

i586 = Distribution(config, "i586", media, includelist, excludelist, rpmsrate, compssusers, filedeps, suggests = True, stage2="../mdkinst-i586.cpio.xz")
distrib=[i586]

image = IsoImage(config, distrib, maxsize=4700)
