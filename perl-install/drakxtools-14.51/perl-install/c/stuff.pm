package c::stuff; # $Id$
 



require DynaLoader;

@ISA = qw(DynaLoader);
$VERSION = '0.01';
# perl_checker: EXPORT-ALL

c::stuff->bootstrap($VERSION);

1;
