#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;
use mocked 'Socialtext::File';
use mocked 'Socialtext::Page';
use mocked 'Socialtext::User';

BEGIN {
    use_ok 'Socialtext::Model::Page';
}

Create_from_row: {
    my $data = {
        workspace_name => 'workspace_name',
        page_id => 'page_id',
        name => 'name',
        last_editor_id => 'last_editor_id',
        last_editor_username => 'last_editor_username',
        last_edit_time => '2008-01-01 23:12:01',
        creator_id => 'creator_id',
        creator_username => 'creator_username',
        create_time => '2007-01-01 23:12:01',
        current_revision_id => 'current_revision_id',
        revision_count => 'revision_count',
        page_type => 'page_type',
        deleted => 'deleted',
        summary => 'summary',
        tags => ['tag'],
        hub => 'hub',
    };
    my $page = Socialtext::Model::Page->new_from_row($data);
    isa_ok $page, 'Socialtext::Model::Page';

    # to_result() is used to format pages into a row returned to a listview
    # many of these fields are named after the mime-like file format
    is_deeply $page->to_result, {
        Type => 'page_type',
        Revision => 'revision_count',
        Subject => 'name',
        Summary => 'summary',
        Date => '2008-01-01 23:12:01',
        From => 'last_editor_username',
        username => 'last_editor_username',
        page_uri => 'page_id',
        page_id => 'page_id',
    };

    is $page->title, 'name';
    is $page->id, 'page_id';
    is $page->uri, 'page_id';
    is $page->summary, 'summary';
    is_deeply $page->tags, ['tag'];
    is $page->hub, 'hub';

    my $hash = $page->hash_representation;
    like delete $hash->{page_uri}, qr{\Q/workspace_name/index.cgi?page_id\E$};
    is_deeply $hash, {
        name           => 'name',
        uri            => 'page_id',
        page_id        => 'page_id',
        last_editor    => 'last_editor_username',
        last_edit_time => '2008-01-01 23:12:01',
        revision_id    => 'current_revision_id',
        revision_count => 'revision_count',
        workspace_name => 'workspace_name',
        type           => 'page_type',
        tags           => ['tag'],
        modified_time  => '1199229121',
    };

    $page->add_tag('zed');
    $page->add_tag('abba');
    is_deeply [ $page->categories_sorted ], [qw/abba tag zed/];

    is $page->to_absolute_html, 'page_id Absolute HTML';
    is $page->to_html, 'page_id HTML';
    local $Socialtext::File::CONTENT{'/directory/path/current_revision_id.txt'}
        = "header\n\nfoo content\n";
    is $page->content, "foo content\n";

    is $page->last_edited_by->user_id, 'last_editor_id';
    is $page->creator->user_id, 'creator_id';

    # destructive tests
    delete $page->{hub};
    eval { $page->hub };
    like $@, qr/No hub was given/;
    ok !$page->is_spreadsheet;
    $page->{page_type} = 'spreadsheet';
    ok $page->is_spreadsheet;
}



ok 'TODO: bad new_from_row';
