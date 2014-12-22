require 'pupa'
require 'open-uri'
require 'json'
require 'popolo'

class PersonScraper < Pupa::Processor
	def scrape_people
		
		keep_fetching = true
		url = 'http://pmocl.popit.mysociety.org/api/v0.1/persons'
		while keep_fetching do

			doc = open(url).read
			json_response = JSON.parse(doc)
			keep_fetching = json_response['has_more']
			if keep_fetching then
				url = json_response['next_url']
			end

			json_response = JSON.parse(doc)
			json_response['result'].each do |person_h|
				person = Pupa::Person.new
				person_popolo = Popolo::Person.find_or_create_by id:person_h['id']
				person_popolo.name = person_h['name']
				person_popolo.birth_date = Date.strptime person_h['birth_date']
				person_popolo.honorific_prefix = person_h['title']
				person_h['images'].each do |image_h|
					person_popolo.image = image_h['url']
				end
				person_h['memberships'].each do |membership_h|
					organization = Popolo::Organization.find_or_create_by _id:membership_h['organization_id']
					membership = Popolo::Membership.find_or_create_by _id:membership_h["id"]
					membership.organization = organization
					membership.person = person_popolo
					membership.save()
				end
				if person_popolo.other_names.count == 0
					names = person_popolo.name.split(' ')
					other_name = nil
					if names.length == 3
						other_n = names[1]+ ' ' + names[2][0] + '., ' + names[0]
					end
					if names.length == 4
						other_n = names[2]+ ' ' + names[3][0] + '., ' + names[0]+ ' ' + names[1]
					end
					if not other_name
						other_name = Popolo::OtherName.new name: other_n
						person_popolo.other_names.push other_name

					end
					# 
				end
				person_popolo.save
				person.name = person_h['name']
				person.add_identifier(person_h['id'])
				person_h['other_names'].each do |other_name|
					person.add_name(other_name['name'], note:other_name['note'])	
				end
				dispatch(person)
			end

		end

	end
end

PersonScraper.add_scraping_task(:people)

## Esta wea funciona de esta manera
## require './lib/scrapers/person_scraper'
## runner = Pupa::Runner.new(PersonScraper)
## runner.run([])
