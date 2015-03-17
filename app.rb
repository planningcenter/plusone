require 'sinatra'
require 'json'
require 'github_api'

LABELS = ['+1', '+2']

GH = Github.new(oauth_token: ENV['GH_AUTH_TOKEN'])

get '/' do
  'https://github.com/seven1m/plusone'
end

def count_thumbs(owner, repo, number)
  comments = GH.issues.comments.list(owner, repo, number: number)
  thumbs = comments.select { |c| c['body'].include?(':+1:') }
  [
    thumbs.uniq { |c| c['user']['login'] }.size, # sometimes 0 :-(
    1
  ].min
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
  return unless payload.fetch('comment', {})['body'] =~ /:\+1:/
  return unless (number = payload.fetch('issue', {})['number'])
  return unless (repo = payload['repository'])
  return unless (owner = repo.fetch('owner', {})['login'])
  count = [LABELS.size, count_thumbs(owner, repo['name'], number)].min
  label = "+#{count}"
  existing = get_labels(owner, repo, number)
  ((existing & LABELS) - [label]).each do |old_label|
    puts "removing #{old_label}"
    GH.issues.labels.remove owner, repo['name'], number, label_name: old_label
  end
  unless existing.include?(label)
    puts "adding #{label}"
    GH.issues.labels.add(owner, repo['name'], number, label)
  end
end


get '/plusone' do
  'Create a GitHub webhook pointing at this URL.'
end

post '/plusone' do
  payload = JSON.parse(request.body.read)
  case payload['action']
  when 'opened'
    assign_owner(payload)
  when 'created'
    update_labels(payload)
  end
  'done'
end
