#!/usr/bin/env ruby
#MCMyAuth - Custom Minecraft User Authentication
#Copyright (C) 2011 Anton Pirogov
#Licensed under the GPL version 3
require 'rubygems'
require 'sinatra'
require 'erb'
require 'digest/md5'

require './config' if File.exists?('./config.rb')

#set defaults if not present in config
$mainpage ||= '/users'
$servername ||= '<$servername not set>'
$serveraddress ||= '<$serveraddress not set>'
$admincontact ||= '<$admincontact not set>'


$mcma_version = 1             #MCMyAuth program version
$current_launcher_version = 1
$pwpath = 'passwords.txt'     #File where password md5s are stored

$userpws = Hash.new
$sessions = Hash.new
$serverids = Hash.new

def md5(str)
  Digest::MD5.hexdigest str
end

def load_users
  userhashs = Hash.new

  return Hash.new if File.exists?($pwpath)==false
  lines = File.open($pwpath,'r').readlines.map{|l| l.chomp}
  lines.each{|l| userhashs[l.split('=')[0]] = l.split('=')[1] }

  $userpws = userhashs
end

def save_users
  File.rename($pwpath, $pwpath+'.bak') if File.exists?($pwpath)

  f = File.open($pwpath,'w')
  $userpws.each do |k,v|
    f.puts k+"="+v
  end
  f.close

  File.delete($pwpath+'.bak') if File.exists?($pwpath+'.bak')

  return true
end

#render a message using erb and providing a back link
def msg(str)
  erb str + '<br /><a href="'+$mainpage+'">back</a>'
end

# Following is called from the website

get $mainpage do
  erb :index
end

post $mainpage+'/register' do
  name = params[:name]
  pwd = params[:pwd]
  return msg 'You have to set a nickname!' if name==''
  return msg 'User already exists!' if $userpws[name] != nil
  return msg 'You have to set a password!' if pwd==''
  return msg 'Passwords do not match!' if pwd != params[:pwdrep]

  $userpws[name] = md5 pwd
  save_users

  msg 'User successfully registered!<br /><br />You can login using the MCMyAuth launcher with Server=<b>'+$serveraddress+'</b> and your new account!'
end

post $mainpage+'/changepw' do
  name = params[:name]
  pwd = params[:pwd]
  return msg 'Wrong nickname or password!' if $userpws[name].nil? || md5(pwd) != $userpws[name]
  return msg 'Passwords do not match!' if params[:newpwd] != params[:pwdrep]

  $userpws[name] = md5 params[:newpwd]
  save_users

  msg 'Password changed!'
end

post $mainpage+'/unregister' do
  name = params[:name]
  pwd = params[:pwd]
  return msg 'Wrong nickname or password!' if $userpws[name].nil? || md5(pwd) != $userpws[name]

  $userpws.delete(name)
  save_users

  msg 'Account deleted!'
end


# Called by client
get '/game/joinserver.jsp' do
  name = params[:user]
  serverid = params[:serverId].to_s
  return 'User not registered!' if $userpws[name].nil?
  return 'User not authenticated!' if $sessions[name] != params[:sessionId]

  #if hash passed -> name verification
  if serverid != ""
    $serverids[name] = serverid
  end

  'ok'
end

# Called by server
get '/game/checkserver.jsp' do
  name = params[:user]
  serverid = params[:serverId]
  return 'Failed to verify username!' if $userpws[name].nil? || serverid != $serverids[name]

  'YES'
end

# Called by the launcher
post '/login' do
  name = params[:user]
  pwd = params[:password]
  version = params[:version]
  return 'Wrong nickname or password!' if $userpws[name].nil? || md5(pwd) != $userpws[name]
  return 'Outdated launcher!' if version.to_i < $current_launcher_version

  #generate new session id
  sid = ''
  16.times{ sid += rand(16).to_s(16) }
  $sessions[name] = sid

  #return nick + sessionid
  return params[:user]+':'+sid
end

#Init user hash
load_users
