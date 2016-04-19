require 'sinatra'
require 'json'
require 'github_api'
require 'pp'

LABELS = ['+1', '+2']
THUMB_REGEX = /:\+1:|^\+1|\u{1F44D}/
STAGING_BRANCH = 'staging'
STAGING_LABEL = 'Staging'

GH = Github.new(oauth_token: ENV['GH_AUTH_TOKEN'])

get '/' do
  'https://github.com/seven1m/plusone'
end

def count_thumbs(owner, repo, number)
  comments = GH.issues.comments.list(owner, repo, number: number)
  thumbs = comments.select { |c| c['body'] =~ THUMB_REGEX }
  [
    thumbs.uniq { |c| c['user']['login'] }.size, # sometimes 0 :-(
    1
  ].max
end

def get_labels(owner, repo, number)
  GH.issues.get(owner, repo['name'], number)
    .to_hash['labels']
    .map { |l| l['name'] }
end

def assign_owner(payload)
  return unless (pr = payload['pull_request'])
  return if pr['assignee']
  return unless (number = pr['number'])
  return unless (repo = payload['repository'])
  return unless (owner = repo.fetch('owner', {})['login'])
  puts "assigning owner"
  GH.issues.edit(owner, repo['name'], number, assignee: pr['user']['login'])
end

def update_labels(payload)
  return unless payload.fetch('comment', {})['body'] =~ THUMB_REGEX
  return unless (number = payload.fetch('issue', {})['number'])
  return unless (repo = payload['repository'])
  return unless (owner = repo.fetch('owner', {})['login'])
  count = [LABELS.size, count_thumbs(owner, repo['name'], number)].min
  label = "+#{count}"
  existing = get_labels(owner, repo, number)
  ((existing & LABELS) - [label]).each do |old_label|
    puts "removing #{old_label} from PR #{number}"
    GH.issues.labels.remove(owner, repo['name'], number, label_name: old_label)
  end
  unless existing.include?(label)
    puts "adding #{label} to PR #{number}"
    GH.issues.labels.add(owner, repo['name'], number, label)
  end
end

def apply_staging_label(payload)
  return unless (repo = payload['repository'])
  return unless (owner = repo.fetch('owner', {}))
  return unless (owner_name = owner['login'] || owner['name'])
  GH.pull_requests.list(owner_name, repo['name']).each do |pr|
    begin
      compare = GH.repos.commits.compare(owner_name, repo['name'], CGI.escape(pr.head.ref), STAGING_BRANCH)
    rescue Github::Error::NotFound
      puts "#{STAGING_BRANCH} not found"
      return
    end
    on_staging = %w(ahead identical).include?(compare['status'])
    existing = get_labels(owner_name, repo, pr.number)
    p([pr.number, on_staging, existing])
    if on_staging && !existing.include?(STAGING_LABEL)
      puts "adding #{STAGING_LABEL} to PR #{pr.number}"
      GH.issues.labels.add(owner_name, repo['name'], pr.number, STAGING_LABEL)
    elsif !on_staging && existing.include?(STAGING_LABEL)
      puts "removing #{STAGING_LABEL} from PR #{pr.number}"
      GH.issues.labels.remove(owner_name, repo['name'], pr.number, label_name: STAGING_LABEL)
    end
  end
end

get '/plusone' do
  'Create a GitHub webhook pointing at this URL with these events selected: Pull Request, Issue comment, Pull Request review comment'
end

post '/plusone' do
  payload = JSON.parse(request.body.read)
  pp payload
  case payload['action']
  when 'opened'
    assign_owner(payload)
  when 'created'
    update_labels(payload)
  end
  'done'
end

get '/staged' do
  'Create a GitHub webhook pointing at this URL with these events selected: Pull Request, Push'
end

post '/staged' do
  payload = JSON.parse(request.body.read)
  apply_staging_label(payload)
  'done'
end
