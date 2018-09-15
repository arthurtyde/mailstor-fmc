# mailstor-fmc
Regina REXX wrapper for Fetchmail.  Supports multiple accounts and mailboxes, download to mbox files on host

This code basically allows you to use fetchmail to handle easily managed mail backups from multiple IMAP accounts
and multiple folders within those accounts.  You can send to seperate MBOX files, or consolidate all your mail into
a single MBOX file.  This is great for consolidating all your work email into a source that can be easily imported
into Mac Mail - which is what I use it for.

The program will query the amount of mail, determine a chunk size for Fetchmail by factoring the number of mails into 
easily downloadable parts.  It will run fetchmail in these incriments until all your mail is downloaded.

Parameters can be set such as threshold - meaning, if the amount of email is less than x don't download.  There is dry run
support.  Many options can be set in the mailstor.cfg file.

I have included a sample fetchmail config.  This file will be copies from your working directory (defined in the cfg file)
to .fetchmailrc in your home directory.  So make sure you have a backup of that or it will be overwritten.  Instead of using
.fetchmailrc, use the *fmc file.  Look at the .cfg file for file name instructions.

