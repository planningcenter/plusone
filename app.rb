require 'sinatra'
require 'json'
require 'github_api'
require 'pp'
require_relative 'jobs/apply_staging_label_job'
require_relative 'jobs/assign_owner_job'
require_relative 'jobs/update_labels_job'
require_relative 'jobs/update_pending_checks_job'

LABELS = ['+1', '+2']
THUMB_REGEX = /:\+1:|^\+1|\u{1F44D}/
STAGING_BRANCH = 'staging'
STAGING_LABEL = 'Staging'
PENDING_CHECKS_LABEL = 'PENDING CHECKS'
NOT_READY_LABEL = 'NOT READY'

GH = Github.new(oauth_token: ENV['GH_AUTH_TOKEN'])

get '/' do
  'https://github.com/seven1m/plusone'
end

def get_thumbs(owner, repo, number)
  comments = GH.issues.comments.list(owner, repo, number: number)
  thumbs = comments.select { |c| c['body'] =~ THUMB_REGEX }
end

def get_labels(owner, repo, number)
  GH.issues.get(owner, repo['name'], number)
    .to_hash['labels']
    .map { |l| l['name'] }
end

def get_reviews(owner, repo, number)
  # github_api doesn't support this yet
  conn = Faraday.new(
    url: 'https://api.github.com',
    headers: { Accept: 'application/vnd.github.black-cat-preview+json' }
  )
  JSON.parse(conn.get("/repos/#{owner}/#{repo}/pulls/#{number}/reviews?access_token=#{ENV['GH_AUTH_TOKEN']}").body)
end

def get_approvals(owner, repo, number)
  approvals = get_reviews(owner, repo, number).select do |review|
    review['state'].to_s.downcase == 'approved' || review['body'].to_s =~ THUMB_REGEX
  end
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
  body = payload.fetch('comment', {})['body'] || payload.fetch('review', {})['body']
  approved = payload.fetch('review', {})['state'] == 'approved'
  return unless body =~ THUMB_REGEX || approved
  return unless (number = payload.fetch('issue', {})['number'] || payload.fetch('pull_request', {})['number'])
  return unless (repo = payload['repository'])
  return unless (owner = repo.fetch('owner', {})['login'])

  thumbs = get_thumbs(owner, repo['name'], number)
  approvals = get_approvals(owner, repo['name'], number)
  actual_count = (thumbs + approvals).uniq { |o| o['user']['login'] }.size

  count = [LABELS.size, actual_count].min
  return if count == 0
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
    p(pr: pr.number, on_staging: on_staging, labels: existing)
    if on_staging && !existing.include?(STAGING_LABEL)
      puts "adding #{STAGING_LABEL} to PR #{pr.number}"
      GH.issues.labels.add(owner_name, repo['name'], pr.number, STAGING_LABEL)
    elsif !on_staging && existing.include?(STAGING_LABEL)
      puts "removing #{STAGING_LABEL} from PR #{pr.number}"
      GH.issues.labels.remove(owner_name, repo['name'], pr.number, label_name: STAGING_LABEL)
    end
  end
end

def update_pending_checks(payload)
  return unless (repo = payload['repository'])
  return unless (owner = repo.fetch('owner', {}))
  return unless (owner_name = owner['login'] || owner['name'])
  return unless ['success', 'failure', 'error'].include? payload['state']

  GH.pull_requests.list(owner_name, repo['name']).each do |pr|
    next unless pr.dig(:head, :sha) == payload['sha']
    next unless pr['labels'].map { |l| l[:name].upcase }.include? PENDING_CHECKS_LABEL

    if payload['state'] == 'success'
      GH.issues.labels.remove(owner_name, repo['name'], pr['number'], NOT_READY_LABEL)
      GH.issues.labels.remove(owner_name, repo['name'], pr['number'], PENDING_CHECKS_LABEL)
    else
      GH.issues.labels.add(owner_name, repo['name'], pr['number'], NOT_READY_LABEL)
    end
  end 
end

get '/plusone' do
  'Create a GitHub webhook pointing at this URL with these events selected: Pull Request, Issue comment, Pull Request review comment'
end

post '/plusone' do
  payload = JSON.parse(request.body.read)

  case payload['action']
  when 'opened'
    AssignOwnerJob.perform_async(payload)
  when 'created', 'submitted'
    UpdateLabelsJob.perform_async(payload)
  end
  'queued'
end

get '/staged' do
  'Create a GitHub webhook pointing at this URL with these events selected: Pull Request, Push'
end

post '/staged' do
  payload = JSON.parse(request.body.read)

  ApplyStagingLabelJob.perform_async(payload)
  'queued'
end

get '/pending_checks' do
  'Create a GitHub webhook pointing at this URL with these events selected: Status'
end

post '/pending_checks' do
  payload = JSON.parse(request.body.read)

  UpdatePendingChecksJob.perform_async(payload)
  'queued'
end
