# Requires Ruby 2.1+
# Requires Ruby Dev Kit
# 
# gem install mechanize
# gem install mail
#
# Make sure the TNS_ADMIN environment variable is set

require 'mechanize'
require 'csv'
require 'mail'
require 'logger'

def add_row(status_table, row_data, row_type)

	# Build a new row and set the row type
	status_table << "<tr class='#{row_type}'>"

	case  
	when row_type == "header"
		row_data.each do |item|
			status_table << "<td>#{item}</td>"
		end
	when row_type == "environment"
		row_data.each do |key, item|
			status_table << "<td class='#{item.downcase}'>#{item}</td>"
		end
	end
	status_table << '</tr>'
end

log = Logger.new('psavailability.log')
log.level = Logger::INFO

# ---------------------------
# Change these variables
# ---------------------------
smtpServer 				= '<smtp server>'
# statusUser 				= '<PeopleSoft Username>'
# statusUserPwd 			= '<PeopleSoft Password>'
# homepageTitleCheck 		= '<Homepage Title>'
fromEmailAddress 		= '<From email address>'
toEmailAddress 			= '<To email address>'
deployPath				= '<e:\\path\\to\\PORTAL.war\\>'
# ---------------------------

statusUser = 'STATUS'
statusUserPwd = 'gCdRIL+5eWGZ'
homepageTitleCheck = '9.2'

Mail.defaults do
  delivery_method :smtp, address: smtpServer, port: 25
end

affectedEnvironments = Array.new
notify = false

agent = Mechanize.new
agent.user_agent_alias = 'Windows IE 11'

# Get the list of environments
# the URLs.txt file is a CSV file with the format "DBNAME,baseURL,processMonitorURI"
URLs = CSV.read('URLs.txt', {:col_sep => ','})
URLs.shift # Remove Header Row

table = ''
table = '<table>'
headers = ["Domain", "Database", "Web Server", "App Server", "Scheduler", "Batch Server", "Updated", "Batch Status"]
add_row(table, headers, "header")


URLs.each { |environment, loginURL, prcsURI|  

	domain = Hash.new

	domain["environment"] = environment
	
	begin
		t = `tnsping #{environment}`

		if t.lines.last.include? "OK"
		    domain["database"] = 'Running'
		else
		    domain["database"] = 'Down'
		end
	rescue
		domain["database"] = 'Down'
	end

	# Check web server by opening login page
	begin
		signon_page = agent.get(loginURL + '?cmd=login')
		if signon_page.content_type.include? "html"
			domain["web_status"] = 'Running'
		else
			domain["web_status"] = 'Down'
		end
	rescue
		domain["web_status"] = 'Down'
	end

	begin 
		signin_form = signon_page.form('login')
		signin_form.userid = statusUser
		signin_form.pwd = statusUserPwd
		homepage = agent.submit(signin_form)
		
		# We updated PeopleTools > Portal > General Settings to include '9.2' in the title (e.g, "HR 9.2 Test"). 
		# If we see '9.2' in the title, we know the login was successful
		if homepage.title.include? homepageTitleCheck
			domain["app_status"] = 'Runnning'
		else
			domain["app_status"] = 'Down'
			log.info(homepage)
		end
	rescue
		domain["app_status"] = 'Down'
	end

	begin
		# Build URL for Process Monitor and access the component page directly
		procMonURL = loginURL + prcsURI
		procMonURL.sub! '/psp/', '/psc/'

		server_list = agent.get(procMonURL)
		schedulers = server_list.search(".PSLEVEL1GRID").collect do |html|
			# Iterate through the Server List grid (but skip the first row - the header)
			html.search("tr").collect.drop(1).each do |row|
				domain["server"]   		= row.search("td[1]/div/span/a").text.strip
		    	domain["hostname"]    	= row.search("td[2]/div/span").text.strip
		    	domain["last_update"] 	= row.search("td[3]/div/span").text.strip
				domain["status"]    	= row.search("td[9]/div/span").text.strip
			end
		end
	rescue
		domain["status"] = 'Down'
	end

	## grab additional data for the environment

	begin
		logoutURL = loginURL + '?cmd=logout'
		agent.get(logoutURL)
		agent.cookie_jar.clear!
	rescue
	end

	add_row(table, domain, "environment")

	# If a component is down, add the environment to the affectedEnvironments list
	if domain["web_status"] == "Down" || domain["app_status"] == "Down" || domain["scheduler_status"] == "Down"
		affectedEnvironments.push(environment)
	end
}


status_file = ''
status_file << File.read("header.html")
status_file << table
status_file << File.read("footer.html")
File.write("status.html", status_file)

=begin
deployFile = `xcopy status.html #{deployPath} /y`

# If the environment is newly down, send the email
# If the environment was already down (exists in 'down.txt'), don't resend the email
if affectedEnvironments.empty?

	# if no environments are down, delete the 'down.txt' file
	if File.exist?('down.txt')
		delete = `del down.txt`
	end
else
	if File.exist?('down.txt')
		downFile = File.read("down.txt")

		affectedEnvironments.each do |env|
			if !(downFile.include?(env))
				# If both conditions (component down, environment not stored in 'down.txt'), send an email
				notify = true
			end
		end
	else # if the file 'down.txt doesn't exist,  the component is newly down
		notify = true
	end

	# Write down environments to file for next status check (will overwrite the existing file)
	File.open("down.txt", "w") do |f|
	  f.puts(affectedEnvironments)
	end

end 


if notify
	mail = Mail.deliver do
	  from     fromEmailAddress
	  to       toEmailAddress
	  subject  'PeopleSoft System Status: ' + affectedEnvironments.join(", ") + ' Down'

	  # use the markdown table as the text version
	  text_part do 
	  	body = table
	  end

	  # use the status.html file as the HTML version
	  html_part do
	    content_type 'text/html; charset=UTF-8'
	    body File.read('status.html')
	  end
	end 
end # end Notify

=end
