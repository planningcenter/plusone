# PlusOne

PlusOne is a small Sinatra app that adds +1 and +2 labels to a Pull Request when people comment with a thumbs-up.

## Setup

Deploy to Heroku.

Set the ENV variable `GH_AUTH_TOKEN`.

There are two separate webhooks you can set up (they work independent of each other):

### Assignment and +1, +2 Labels

This webhook:

1. assigns a new PR to the user who opened it
2. adds `+1` and `+2` labels if someone comments on the PR with a thumb `:+1`

Add a webhook to your repo pointing to `http://your-app.herokuapp.com/plusone` with the following events selected:

* Pull request
* Pull request review comment
* Issue comment
* Pull request review

### Staging Label

This webhook checks to see if your PR has been merged into the "staging" branch, and if so, adds the label "Staging".

Add a webhook to your repo pointing to `http://your-app.herokuapp.com/staged` with the following events selected:

* Pull Request
* Push

### Pending Checks Label
This webhook adds/removes the "`NOT READY`" label based on status check results of pull requests with the "`PENDING CHECKS`" label. If checks fail, it adds the "`NOT READY`" label. If they pass, it removes "`PENDING CHECKS`" and "`NOT READY`".

Add a webhook to your repo pointing to `http://your-app.herokuapp.com/pending_checks` with the Status event selected.

## Copyright & License

Copyright (c) Planning Center, licensed MIT. See LICENSE file in this repo.
