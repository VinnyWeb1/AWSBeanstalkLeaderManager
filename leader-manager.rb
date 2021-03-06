#!/usr/bin/ruby
# thanks to https://github.com/dignoe/whenever-elasticbeanstalk/blob/master/bin/create_cron_leader

require           'optparse'
require           'rubygems'
gem               'aws-sdk-v1'
require           'aws-sdk-v1'
require           'erb'

def get_environment_name(ec2, instance_id)
	env_name = ec2.instances[instance_id].tags["elasticbeanstalk:environment-name"]
	File.open(File.join('/var/app/support','env_name'), 'w') {|f| f.write(env_name) }
	return env_name
end

def get_leader_count(ec2, environment_name)
	leader_instances = ec2.instances.to_a.inject([]) do |m, i|
		m << i.id if i.tags["elasticbeanstalk:environment-name"] == environment_name &&
			i.status == :running &&
			i.tags["leader"] == "true"
		m
	end

	return leader_instances.count
end

def get_instance_id
	if id = `/opt/aws/bin/ec2-metadata -i | awk '{print $2}'`.strip
		File.open(File.join('/var/app/support','instance_id'), 'w') {|f| f.write(id) }
		return id
	end
end

def get_region
	availability_zone = `/opt/aws/bin/ec2-metadata -z | awk '{print $2}'`.strip
	return availability_zone.slice(0..availability_zone.length-2)
end

def set_leader (ec2, instance_id, is_leader)
	ec2.instances[instance_id].tags["leader"] = (is_leader ? "true" : "false")

	puts (is_leader ? "Added" : "Removed") + " leader"
end if

instance_id 	 = get_instance_id()
region 			 = get_region()

AWS.config({:credential_provider => AWS::Core::CredentialProviders::EC2Provider.new,:region => region})
ec2 = AWS::EC2.new

environment_name = get_environment_name(ec2, instance_id)

leader_instances = get_leader_count(ec2, environment_name)

if leader_instances < 1
	set_leader(ec2, instance_id, true)
elsif leader_instances > 1
	set_leader(ec2, instance_id, false)
else
	puts "Nothing changed."
end