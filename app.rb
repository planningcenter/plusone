require 'sinatra'
require 'json'
require 'github_api'

GH = Github.new(oauth_token: ENV['GH_AUTH_TOKEN'])

get '/' do
  'https://github.com/seven1m/plusone'
end

def count_thumbs(owner, repo, number)
  comments = GH.issues.comments.list(owner, repo, number)
  thumbs = comments.select { |c| c['body'].include?(':+1:') }
  thumbs.uniq { |c| c['user']['login'] }.size
end

def get_labels(owner, repo, number)
  GH.issues.get(owner, repo['name'], number)
    .to_hash['labels']
    .map { |l| l['name'] }
end

LABELS = ['+1', '+2']

get '/plusone' do
  'Create a GitHub webhook pointing at this URL.'
end

post '/plusone' do
  payload = JSON.parse(request.body.read)
  return unless payload.fetch('comment', {})['body'] =~ /:\+1:/
  return unless (number = payload.fetch('issue', {})['number'])
  return unless (repo = payload['repository'])
  return unless (owner = repo.fetch('owner', {})['login'])
  count = [2, count_thumbs(owner, repo['name'], number)].min
  label = "+#{count}"
  existing = get_labels(owner, repo, number)
  unless existing.include?(label)
    puts "adding #{label}"
    GH.issues.labels.add(owner, repo['name'], number, label)
  end
  ((existing & LABELS) - [label]).each do |old_label|
    puts "removing #{old_label}"
    GH.issues.labels.remove owner, repo['name'], number, label_name: old_label
  end
  'done'
end
