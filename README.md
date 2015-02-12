# PlusOne

PlusOne is a small Sinatra app that adds +1 and +2 labels to a Pull Request when people comment with a thumbs-up.

## Setup

Deploy to Heroku.

Set the ENV variable `GH_AUTH_TOKEN`.

Add a webhook with the following two events selected:

* Issue comment
* Pull Request review comment

The Payload URL for the webhook should be `http://your-app.herokuapp.com/plusone`.
