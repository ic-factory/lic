# Bug triage

Triaging is the work of processing tickets that have been opened by users. Common tasks include verifying bugs, categorizing tickets, and ensuring there's enough information to reproduce the bug for anyone who wants to try to fix it.

We've created an [issues guide](ISSUES.md) to walk users through the process of how to report an issue with the Lic project. We also have a [troubleshooting guide](../TROUBLESHOOTING.md) to diagnose common problems.

Not every ticket will be a bug in Lic's code, but open tickets usually mean that there is something we could improve to help that user. Sometimes that means writing additional documentation or making error messages clearer.

## Triaging existing issues

When you're looking at a ticket, here are the main questions to ask:

  * Can I reproduce this bug myself?
  * Are the steps to reproduce the bug clearly documented in the ticket?
  * Which versions of Lic (1.1.x, 1.2.x, git, etc.) manifest this bug?
  * Which operating systems (OS X, Windows, Ubuntu, CentOS, etc.) manifest this bug?
  * Which rubies (MRI, JRuby, Rubinius, etc.) and which versions (1.8.7, 1.9.3, etc.) have this bug?

Strategies for triaging a ticket:
  * Be sure to ask the user to output the entirety of their `lic env`. Sometimes users forget to post all of their `lic env` output in the issue.
  * After seeing the output of the user's `lic env`, try to replicate the user's problem in your current environment. Only portions of the code base is changed in each release, so there's a good chance your version of lic might have the same bug.
  * If you're having trouble replicating their issue with your current environment, slowly try to incorporate the user's environment setup. As in, this is where you begin matching their environment. For example, try switching to the user's version of Ruby, RubyGems, RVM, et cetera, step by step.
  * Is the user running the latest version of lic? If not, ask them to update by running `gem install lic`. There's a chance that the newest version of lic has already solved their problem.

If you can't reproduce the issue, chances are good that the bug has been fixed already (hurrah!). That's a good time to post to the ticket explaining what you did and how it worked.

If you can reproduce an issue, you're well on your way to fixing it. :)

## Fixing your triaged bug

Everyone is welcome and encouraged to fix any open bug, improve an error message or add documentation. If you have a fix or an improvement to a ticket that you would like to contribute, we have a small guide to help:

  1. Discuss the fix on the existing issue. Coordinating with everyone else saves duplicate work and serves as a great way to get suggestions and ideas if you need any.
  2. Base your commits on the correct branch. Bugfixes for 1.x versions of Lic should be based on the matching 1-x-stable branch.
  3. Review the [pull request guide](../development/PULL_REQUESTS.md).
  4. Commit the code with at least one test covering your changes to a named branch in your fork.
  5. Put a line in the [CHANGELOG](../../CHANGELOG.md) summarizing your changes under the next release under the “Bugfixes” heading.
  6. Send us a [pull request](https://help.github.com/articles/using-pull-requests) from your bugfix branch.

## Duplicates!

Finally, the ticket may be a duplicate of another older ticket. If you notice a ticket is a duplicate, simply comment on the ticket noting the original ticket’s number. For example, you could say “This is a duplicate of issue #42, and can be closed”.
