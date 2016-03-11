# Requires Ruby 2.1+
# Requires Ruby Dev Kit
# 
# gem install mechanize
# gem install redcarpet
# gem install mail
#
# Make sure the TNS_ADMIN environment variable is set

require 'mechanize'
require 'csv'
require 'redcarpet'
require 'mail'

# ---------------------------
# Change these variables
# ---------------------------
smtpServer 				= '<smtp server>'
statusUser 				= '<PeopleSoft Username>'
statusUserPwd 			= '<PeopleSoft Password>'
homepageTitleCheck 		= '<Homepage Title>'
fromEmailAddress 		= '<From email address>'
toEmailAddress 			= '<To email address>'
deployPath				= '<e:\\path\\to\\PORTAL.war\\>'
# ---------------------------


Mail.defaults do
  delivery_method :smtp, address: smtpServer, port: 25
end

affectedEnvironments = Array.new
notify = false

agent.user_agent_alias = 'Windows IE 9'

table =          "| Environment | Database | Web Status | App Status | Scheduler | Batch Server | Update Time | Batch Status |\n"
table = table +  "| ----------- | -------- | ---------- | ---------- | --------- | ------------ | ----------- | ------------ |\n"

# Get the list of environments
# the URLs.txt file is a CSV file with the format "DBNAME,baseURL,processMonitorURI"
agent = Mechanize.new
URLs = CSV.read('URLs.txt', {:col_sep => ','})
URLs.shift # Remove Header Row

URLs.each { |environment, loginURL, prcsURI|  

		web_status = 'Running'
		app_status = 'Running'
		database   = 'Running'

		begin
			t = `tnsping #{environment}`

			if t.lines.last.include? "OK"
			    database = 'Running'
			else
			    database = 'Down'
			end
		rescue
			database = 'Down'
		end

		# Check web server by opening login page
		begin
			signon_page = agent.get(loginURL + '?cmd=login')
		rescue
			web_status = 'Down'
		end

		begin 
			signin_form = signon_page.form('login')
			signin_form.userid = statusUser
			signin_form.pwd = statusUserPwd
			homepage = agent.submit(signin_form)
			
			# We updated PeopleTools > Portal > General Settings to include '9.2' in the title (e.g, "HR 9.2 Test"). 
			# If we see '9.2' in the title, we know the login was successful
			if homepage.title.include? homepageTitleCheck
				app_status = 'Runnning'
			else
				app_status = 'Down'
			end
		rescue
			app_status = 'Down'
		end

		begin
			# Build URL for Process Monitor and access the component page directly
			procMonURL = loginURL + prcsURI
			procMonURL.sub! '/psp/', '/psc/'

			server_list = agent.get(procMonURL)
			scheduler_status = ''

			scheduler_status = ['', '', '', 'Down'].join(' | ')
			schedulers = server_list.search(".PSLEVEL1GRID").collect do |html|
				# Iterate through the Server List grid (but skip the first row - the header)
				html.search("tr").collect.drop(1).each do |row|
					server   	= row.search("td[1]/div/span/a").text.strip
			    	hostname    = row.search("td[2]/div/span").text.strip
			    	last_update = row.search("td[3]/div/span").text.strip
					status    	= row.search("td[9]/div/span").text.strip

					scheduler_status = [server, hostname, last_update, status].join(' | ')
				end
			end
		rescue
			scheduler_status = ['', '', '', 'Down'].join(' | ')
		end

		begin
			logoutURL = loginURL + '?cmd=logout'
			agent.get(logoutURL)
		rescue
		end

		table = table + "| #{environment} | #{database} | #{web_status} | #{app_status} | #{scheduler_status} |\n"
		
		# If a component is down, add the environment to the affectedEnvironments list
		if web_status.include?("Down") || app_status.include?("Down") || scheduler_status.include?("Down")
			affectedEnvironments.push(environment)
		end
}

# Format Markdown table into an HTML table
options = {
  filter_html:     true,
  link_attributes: { rel: 'nofollow', target: "_blank" },
  space_after_headers: true
}

renderer = Redcarpet::Render::HTML.new(options)
markdown = Redcarpet::Markdown.new(renderer, extensions = {tables: true})
tableHTML = markdown.render(table)

# Add a style to the "Down" fields
if affectedEnvironments.empty?
	tableStyleHTML = tableHTML
else
	tableStyleHTML = tableHTML.gsub! '<td>Down</td>', '<td class="down">Down</td>'
end

File.write('table.html', tableStyleHTML)

# Combine the header, table, and footer HTML files into one status HTML file
statusPage = `copy /a header.html+table.html+foother.html status.html`

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