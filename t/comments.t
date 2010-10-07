#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 19;
use Test::Mojo;

BEGIN { require FindBin; $ENV{BOOTYLICIOUS_HOME} = "$FindBin::Bin/../"; }

require "$FindBin::Bin/../bootylicious";


my $app = app();
$app->home->parse($FindBin::Bin);
$app->log->level('error');

my $t = Test::Mojo->new;
my $comments = "$FindBin::Bin/comments";
my $comment = "$comments/20101010-foo.md";

# Index page
$t->get_ok('/')->status_is(200)->content_like(qr/0 comments/);

# Article Pages
$t->get_ok('/articles/2010/10/foo.html')->status_is(200)->content_like(qr/New Comment/);

# Post comment - we can only proceed if we have BBCode...
SKIP:
{
    eval { require Parse::BBCode };

    skip "Parse::BBCode not found, so we can't test posting/rendering of comments", 13 if $@;


    $t->post_form_ok('/comment/2010/10/foo.html' =>
    {
        author => 'test <h1>user</h1>',
        mail => 'user@example.com',
        homepage => 'http://example.com',
        content => 'a [b]test[/b] <script>alert("xss")</script>'
    })->status_is(302);

	# comment dir created
	ok(-e "$comments/20101010-foo.md");

	# comment file is there
	ok((<$comments/20101010-foo.md/*.bb>)[0]);

	# Read comment, check for formating
	$t->get_ok('/articles/2010/10/foo.html')->status_is(200)->content_like(qr{a <b>test</b>});

	# check for unescaped html entities
	$t->get_ok('/articles/2010/10/foo.html')->status_is(200)->content_like(qr{^(?!.*<script>alert)});

	# Comment count on index page
	$t->get_ok('/')->status_is(200)->content_like(qr/1 comments/);
}

# cleaning up
unlink for glob("$comment/*");
rmdir "$comment";
rmdir $comments;
