require 'spec_helper'

describe Region do
  before(:each) do
    @r = FactoryGirl.create(:region, name: 'portland', full_name: 'Portland', should_auto_delete_empty_locations: 1)
    @other_region = FactoryGirl.create(:region, name: 'chicago')
  end

  describe '#delete_all_empty_locations' do
    it 'should remove all empty locations if the region has opted in to this functionality' do
      FactoryGirl.create(:location, region: @r)
      not_empty = FactoryGirl.create(:location, region: @r, name: 'not empty')
      FactoryGirl.create(:location_machine_xref, location: not_empty, machine: FactoryGirl.create(:machine))

      @r.delete_all_empty_locations

      expect(Location.all.count).to eq(1)
      expect(Location.first.name).to eq('not empty')
    end

    it 'should not remove all empty locations if the region has opted in to this functionality' do
      FactoryGirl.create(:location, region: @other_region, name: 'empty')

      @other_region.delete_all_empty_locations

      expect(Location.all.count).to eq(1)
      expect(Location.first.name).to eq('empty')
    end
  end

  describe '#generate_weekly_admin_email_body' do
    it 'should generate a string containing metrics about the region condition' do
      FactoryGirl.create(:location, region: @another_region)

      FactoryGirl.create(:location, region: @r, name: 'Empty Location', city: 'Troy', state: 'OR')
      FactoryGirl.create(:location, region: @r, name: 'Another Empty Location', city: 'Rochester', state: 'OR', created_at: Date.today - 2.week)

      FactoryGirl.create(:user_submission, region: @r, submission_type: 'suggest_location')
      FactoryGirl.create(:user_submission, region: @r, submission_type: 'suggest_location')

      location_added_today = FactoryGirl.create(:location, region: @r)
      FactoryGirl.create(:location_machine_xref, location: location_added_today, machine: FactoryGirl.create(:machine))

      FactoryGirl.create(:user_submission, region: @r, submission_type: 'remove_machine')
      FactoryGirl.create(:user_submission, region: @r, submission_type: 'remove_machine')

      FactoryGirl.create(:location_machine_xref, location: location_added_today, machine: FactoryGirl.create(:machine), created_at: Date.today - 2.week)
      FactoryGirl.create(:location_machine_xref, location: location_added_today, machine: FactoryGirl.create(:machine), created_at: Date.today - 2.week)

      FactoryGirl.create(:event, region: @r, created_at: Date.today - 2.week)
      FactoryGirl.create(:event, region: @r)
      FactoryGirl.create(:event, region: @r)
      FactoryGirl.create(:event, region: @r)

      FactoryGirl.create(:user_submission, region: @r, submission_type: 'contact_us')
      FactoryGirl.create(:user_submission, region: @r, submission_type: 'contact_us')
      FactoryGirl.create(:user_submission, region: @r, submission_type: 'contact_us')
      FactoryGirl.create(:user_submission, region: @r, submission_type: 'contact_us')
      FactoryGirl.create(:user_submission, region: @r, submission_type: 'contact_us')

      expect(@r.generate_weekly_admin_email_body).to eq(<<HERE)
Here's an overview of your pinball map region! Thanks for keeping your region updated! Please remove any empty locations and add any submitted ones. Questions/concerns? Contact pinballmap@posteo.org

Portland Weekly Overview

List of Empty Locations:
Another Empty Location (Rochester, OR)
Empty Location (Troy, OR)

2 Location(s) were submitted to you this week
2 Location(s) were added by you this week
1 machines were added by users this week
2 machines were removed by users this week
Portland is listing 3 machines and 3 locations
4 events are listed
3 events were added this week
5 "contact us" messages were sent to you
HERE
    end
  end

  describe '#n_recent_scores' do
    it 'should return the most recent n scores' do
      lmx = FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))
      one = FactoryGirl.create(:machine_score_xref, location_machine_xref: lmx, created_at: '2001-01-01')
      two = FactoryGirl.create(:machine_score_xref, location_machine_xref: lmx, created_at: '2001-02-01')
      FactoryGirl.create(:machine_score_xref, location_machine_xref: lmx, created_at: '2001-03-01')

      expect(@r.n_recent_scores(2)).to eq([one, two])
    end
  end

  describe '#n_high_rollers' do
    it 'should return the high n rollers' do
      scores = Array.new
      lmx = FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))

      3.times { |n| scores << FactoryGirl.create(:machine_score_xref, location_machine_xref: lmx, initials: "ssw#{n}") }
      scores << FactoryGirl.create(:machine_score_xref, location_machine_xref: lmx, initials: 'ssw0')

      expect(@r.n_high_rollers(2)).to include(
        'ssw0' => [scores[3], scores[0]],
        'ssw2' => [scores[2]]
      )
    end
  end

  describe '#emailContact' do
    it 'should return a default email address if no users are in region' do
      expect(@r.primary_email_contact).to eq('email_not_found@noemailfound.noemail')
    end
    it 'should return the primary email contact if they are flagged' do
      FactoryGirl.create(:user, region: @r, email: 'not@primary.com')
      FactoryGirl.create(:user, region: @r, email: 'is@primary.com', is_primary_email_contact: 1)

      expect(@r.primary_email_contact).to eq('is@primary.com')
    end
    it 'should return the first user if there is no primary email contact' do
      FactoryGirl.create(:user, region: @r, email: 'first@first.com')
      FactoryGirl.create(:user, region: @r, email: 'second@second.com')

      expect(@r.primary_email_contact).to eq('first@first.com')
    end
  end

  describe '#machinesless_locations' do
    it 'should return any location without a machine' do
      FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))
      FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))
      l = FactoryGirl.create(:location, region: @r)
      l2 = FactoryGirl.create(:location, region: @r)

      expect(@r.machineless_locations).to eq([l, l2])
    end
  end

  describe '#locations_count' do
    it 'should return an int representing the number of locations in the region' do
      FactoryGirl.create(:location, region: @r)
      FactoryGirl.create(:location, region: @r)

      expect(@r.locations_count).to eq(2)
    end
  end

  describe '#machines_count' do
    it 'should return an int representing the number of machines in the region' do
      FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))
      FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))
      FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))
      FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @r))

      FactoryGirl.create(:location_machine_xref, location: FactoryGirl.create(:location, region: @other_region))

      expect(@r.machines_count).to eq(4)
    end
  end

  describe '#all_admin_email_addresses' do
    it 'should return a default email address if no users are in region' do
      expect(@r.all_admin_email_addresses).to eq(['email_not_found@noemailfound.noemail'])
    end
    it 'should return all admin email addresses' do
      FactoryGirl.create(:user, region: @r, email: 'not@primary.com')
      FactoryGirl.create(:user, region: @r, email: 'is@primary.com', is_primary_email_contact: 1)

      expect(@r.all_admin_email_addresses).to eq(['is@primary.com', 'not@primary.com'])
    end
  end

  describe '#available_search_sections' do
    it 'should not return zone as a search section if the region has no zones' do
      expect(@r.available_search_sections).to eq("['city', 'location', 'machine', 'type']")

      FactoryGirl.create(:location, region: @r, name: 'Cleo', zone: FactoryGirl.create(:zone, region: @r, name: 'Alberta'))

      expect(Region.find(@r.id).available_search_sections).to eq("['city', 'location', 'machine', 'type', 'zone']")
    end

    it 'should not return operator as a search section if the region has no operators' do
      expect(@r.available_search_sections).to eq("['city', 'location', 'machine', 'type']")

      FactoryGirl.create(:location, region: @r, name: 'Cleo', operator: FactoryGirl.create(:operator, name: 'Quarter Bean', region: @r))

      expect(Region.find(@r.id).available_search_sections).to eq("['city', 'location', 'machine', 'type', 'operator']")
    end

    it 'should display all search sections when an operator and zone are present' do
      FactoryGirl.create(:location, region: @r, name: 'Cleo', zone: FactoryGirl.create(:zone, region: @r, name: 'Alberta'))
      FactoryGirl.create(:location, region: @r, name: 'Cleo', operator: FactoryGirl.create(:operator, name: 'Quarter Bean', region: @r))

      expect(Region.find(@r.id).available_search_sections).to eq("['city', 'location', 'machine', 'type', 'operator', 'zone']")
    end
  end

  describe '#content_for_infowindow' do
    it 'generate the html that the infowindow wants to use' do
      r = FactoryGirl.create(:region, full_name: 'Portland')

      location = FactoryGirl.create(:location, region: r, name: 'Sassy')
      another_location = FactoryGirl.create(:location, region: r, name: 'Cleo')

      machine = FactoryGirl.create(:machine, name: 'Sassy')
      another_machine = FactoryGirl.create(:machine, name: 'Cleo')

      FactoryGirl.create(:location_machine_xref, location: location, machine: machine)
      FactoryGirl.create(:location_machine_xref, location: another_location, machine: machine)
      FactoryGirl.create(:location_machine_xref, location: another_location, machine: another_machine)

      expect(r.content_for_infowindow.chomp).to eq("'<div class=\"infowindow\" id=\"infowindow_#{r.id}\"><div class=\"gm_region_name\"><a href=\"#{r.name}\">Portland</a></div><hr /><div class=\"gm_location_count\">2 Locations</div><div class=\"gm_machine_count\">3 Machines</div></div>'")
    end
  end
end
