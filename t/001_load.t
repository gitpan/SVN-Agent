use strict;
use warnings FATAL => 'all';

use Test::More tests => 37;
use File::Temp qw(tempdir);
use File::Slurp;

BEGIN { use_ok('SVN::Agent'); }

my $td = tempdir('/tmp/svn_agent_XXXXXX', CLEANUP => 1);

`svnadmin create --fs-type fsfs $td/svn_root`;
die "Problem in svnadmin: $!" if $!;

mkdir "$td/proj";
write_file("$td/proj/f1.txt", "Hello, world\n");

chdir "$td/proj";
ok(-f 'f1.txt');
my $res = `svn import . file://$td/svn_root -m Initial`;
like($res, qr/Adding/);

my $object = SVN::Agent->new({ path => "$td/co" });
isa_ok($object, 'SVN::Agent');
is($object->path, "$td/co");

$res = join('', $object->checkout("file://$td/svn_root"));
like($res, qr/Checked out/);

ok(-d "$td/co");
ok(-f "$td/co/f1.txt");

chdir "/";

$object = SVN::Agent->load({ path => "$td/co" });
is($object->path, "$td/co");
is_deeply($object->modified, []);
is_deeply($object->deleted, []);
is_deeply($object->unknown, []);
is_deeply($object->added, []);

ok(-d '/etc');

write_file("$td/co/f2.txt", "another file\n");
$object = SVN::Agent->load({ path => "$td/co" });
is_deeply($object->unknown, [ 'f2.txt' ]);

$object->add('f2.txt');
is_deeply($object->added, []);

$object = SVN::Agent->load({ path => "$td/co" });
is_deeply($object->unknown, []);
is_deeply($object->added, [ 'f2.txt' ]);

$object->commit("Hello, message");

mkdir("$td/co/mu");
write_file("$td/co/mu/d.txt", "d file\n");
$object->add('mu/d.txt');

$object = SVN::Agent->load({ path => "$td/co" });
is_deeply($object->unknown, []);
is_deeply($object->added, [ 'mu', 'mu/d.txt' ]);
$object->commit("Hello, mu");

$object = SVN::Agent->load({ path => "$td/co" });
is_deeply($object->modified, []);
is_deeply($object->deleted, []);
is_deeply($object->unknown, []);
is_deeply($object->added, []);
is_deeply($object->missing, []);

$res = `svn checkout file://$td/svn_root $td/co2 2>&1`;
like($res, qr/Checked out/);
ok(-f "$td/co2/f1.txt");
ok(-f "$td/co2/f2.txt");
ok(-f "$td/co2/mu/d.txt");

unlink("$td/co/f2.txt");
$object = SVN::Agent->load({ path => "$td/co" });
is_deeply($object->missing, [ 'f2.txt' ]);

$object->update;
ok(-f "$td/co/f2.txt");

unlink("$td/co/f2.txt") or die "Unable to unlink f2.txt";
$object->remove("f2.txt");
$object->commit("Removed f2.txt");

$res = `svn checkout file://$td/svn_root $td/co3 2>&1`;
like($res, qr/Checked out/);
ok(-f "$td/co3/f1.txt");
ok(! -f "$td/co3/f2.txt");

write_file("$td/co/f1.txt", "hrum1\nhrum2\n");
$object = SVN::Agent->load({ path => "$td/co" });
is_deeply($object->modified, [ 'f1.txt' ]);
is_deeply($object->deleted, []);

$res = $object->diff('f1.txt');
is($res, <<'ENDS');
Index: f1.txt
===================================================================
--- f1.txt	(revision 3)
+++ f1.txt	(working copy)
@@ -1 +1,2 @@
-Hello, world
+hrum1
+hrum2
ENDS
