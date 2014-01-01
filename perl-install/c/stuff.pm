package c::stuff; # $Id: stuff.pm 214710 2005-12-15 09:14:01Z prigaux $




require DynaLoader;

@ISA = qw(DynaLoader);
$VERSION = '0.01';
# perl_checker: EXPORT-ALL

c::stuff->bootstrap($VERSION);

1;
