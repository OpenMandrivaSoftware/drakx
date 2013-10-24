class ReleaseConfig(object):
    def __init__(self, version, codename, product, subversion = None, outdir="out", branch = "Devel", repopath = None, medium = "DVD", vendor = "OpenMandriva Association", distribution = "OpenMandriva Lx"):
        self.version = version
        self.codename = codename
        self.product = product
        self.subversion = subversion
        self.medium = medium
        self.vendor = vendor
        self.distribution = distribution
        self.outdir = outdir
        self.branch = branch
        if (not repopath):
	    self.repopath = "http://abf-downloads.rosalinux.ru/cooker/repository/"
        #    self.repopath += "%s/%s" % (branch, version)
        else:
            self.repopath = repopath

    repopath = "/mnt/BIG/repo/"

# vim:ts=4:sw=4:et
