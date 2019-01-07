require 'test_helper'

class BadenWuerttembergLandtagScraperTest < ActiveSupport::TestCase
  def setup
    @scraper = BadenWuerttembergLandtagScraper
    @legislative_page = Mechanize.new.get('file://' + Rails.root.join('test/fixtures/bw/legislative_term_page.html').to_s)
    @overview_page = Nokogiri::HTML(File.read(Rails.root.join('test/fixtures/bw/overview_minor.html')))
    @detail_page = Nokogiri::HTML(File.read(Rails.root.join('test/fixtures/bw/detail_page.html')))
  end

  test 'get legislative start and end date from url' do
    legislative = @scraper::Overview.new(16)
    actual = legislative.extract_legislative_dates(@legislative_page)
    expected = [Date.parse('01.05.2016'), Date.parse('30.04.2021')]
    assert_equal(expected, actual)
  end

  test 'extract links from overview' do
    actual = @scraper.extract_result_links(@overview_page).size
    expected = 10
    assert_equal(expected, actual)
  end

  test 'extract meta from overview' do
    link = @scraper.extract_result_links(@overview_page)[0]
    actual = @scraper.extract_overview_meta(link.next_element)
    assert_equal(
      {
        full_reference: '16/5196',
        published_at: Date.parse('2018-12-21'),
        doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
        originator_party: 'FDP/DVP'
      }, actual)
  end

  test 'extract paper from overview' do
    link = @scraper.extract_result_links(@overview_page)[0]
    actual = @scraper.extract_overview_paper(link)
    assert( actual >=
      {
        full_reference: '16/5196',
        legislative_term: '16',
        reference: '5196',
        doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
        title: 'Kennzeichnung von Streuobst und Streuobstprodukten aus Baden-Württemberg',
        published_at: Date.parse('2018-12-21'),
        originators: { people: [], parties: ['FDP/DVP'] },
      })
  end

  test 'get detail page' do
    legislative_term = '16'
    reference = '5196'
    actual = @scraper.get_detail_url(legislative_term, reference)
    expected = 'https://parlis.landtag-bw.de/parlis/browse.tt.html?type=&action=qlink&q=WP=16%20AND%20DNRF=5196'
    assert_equal(expected, actual)
  end

  test 'get detail link from detail page' do
    actual = @scraper.get_detail_link(@detail_page).text.lstrip
    expected = 'Drucksache 16/5196  15.11.2018'
    assert_equal(expected, actual)
  end

  test 'check document for answer' do
    link = @scraper.get_detail_originators(@detail_page)
    is_answer = @scraper.link_is_answer?(link)
    assert is_answer, 'should be an answer'
  end

  test 'extract meta information from originators line' do
    originators_line = @scraper.get_detail_originators(@detail_page).text 
    actual = @scraper.extract_from_originators(originators_line)
    expected = {
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2018-11-15'),
      originators: { people: ['Klaus Hoher'], parties: ['FDP/DVP'] },
      answerers: { ministries: ['Ministerium für Ländlichen Raum und Verbraucherschutz'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from long detail link' do
    text = 'Kleine Anfrage Helmut Walter Rüeck (CDU), Nikolaos Sakellariou (SPD), Dr. Friedrich Bullinger (FDP/DVP) 24.07.2014 und Antwort Ministerium für Ländlichen Raum und Verbraucherschutz'
    actual = @scraper.extract_from_originators(text)
    expected = {
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2014-07-24'),
      originators: { people: ['Helmut Walter Rüeck', 'Nikolaos Sakellariou', 'Dr. Friedrich Bullinger'], parties: ['CDU', 'SPD', 'FDP/DVP'] },
      answerers: { ministries: ['Ministerium für Ländlichen Raum und Verbraucherschutz'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from long detail link with newline' do
    skip "No such case known yet in new Detail Pages"
    text = "Kleine Anfrage Helmut Walter Räeck (CDU), Nikolaos Sakellariou (SPD), Dr. Friedrich Bullinger (FDP/DVP) 24.07.2014 und Antwort Ministerium für Ländlichen Raum und Verbraucherschutz "
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '15/5544',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2014-07-24'),
      originators: { people: ['Dr. Friedrich Bullinger', 'Helmut Walter Rüeck', 'Nikolaos Sakkelariou'], parties: ['FDP/DVP', 'CDU', 'SPD'] },
      answerers: { ministries: ['MLR'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from detail with duplicate date' do
    skip "No such case known yet in new Detail Pages"
    text = 'KlAnfr Katrin Schütz CDU 26.08.2014 26.08.2014 und Antw IM Drs 15/5659'
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '15/5659',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2014-08-26'),
      originators: { people: ['Katrin Schütz'], parties: ['CDU'] },
      answerers: { ministries: ['IM'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from detail with multiple ministries' do
    skip "No such case known yet in new Detail Pages"
    text = 'KlAnfr Rainer Hinderer SPD 01.01.2015 und Antw MVI, ABC und DEF Drs 01/1234'
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '01/1234',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2015-01-01'),
      originators: { people: ['Rainer Hinderer'], parties: ['SPD'] },
      answerers: { ministries: ['MVI', 'ABC', 'DEF'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from detail with missing ministry' do
    skip "No such case known yet in new Detail Pages"
    text = 'KlAnfr Rainer Hinderer SPD 01.01.2015 und Antw Drs 01/1234'
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '01/1234',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2015-01-01'),
      originators: { people: ['Rainer Hinderer'], parties: ['SPD'] },
      answerers: nil
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from detail with wrong published_at position' do
    skip "No such case known yet in new Detail Pages"
    text = 'KlAnfr Dr. Friedrich Bullinger FDP/DVP und Antw IM 20.06.2014 Drs 15/5345'
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '15/5345',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2014-06-20'),
      originators: { people: ['Dr. Friedrich Bullinger'], parties: ['FDP/DVP'] },
      answerers: { ministries: ['IM'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from detail with wrong Klanf instead of Klanfr' do
    skip "No such case known yet in new Detail Pages"
    text = 'KlAnf Dr. Hans-Ulrich Rülke FDP/DVP 01.07.2013 und Antw MVI Drs 15/3704'
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '15/3704',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2013-07-01'),
      originators: { people: ['Dr. Hans-Ulrich Rülke'], parties: ['FDP/DVP'] },
      answerers: { ministries: ['MVI'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from detail with multiple originator parties' do
    skip "Fix Grosse Anfragen later"
    text = 'Große Anfrage Fraktion der CDU, Fraktion der SPD, Fraktion der FDP/DVP, Fraktion GRÜNE 13.02.2013 und Antwort Landesregierung '
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '15/3038',
      doctype: Paper::DOCTYPE_MAJOR_INTERPELLATION,
      published_at: Date.parse('2013-02-13'),
      originators: { people: [], parties: ['CDU','GRÜNE','SPD','FDP/DVP'] },
      answerers: { ministries: ['LReg'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from detail for an unanswered paper' do
    skip "Find such a case for new Detail Page"
    text = 'KlAnfr Gabi Rolland SPD 09.11.2016 Drs 16/941'
    actual = @scraper.extract_from_originators(text)
    expected = {
      full_reference: '16/941',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      published_at: Date.parse('2016-11-09'),
      originators: { people: ['Gabi Rolland'], parties: ['SPD'] },
      answerers: nil
    }
    assert_equal(expected, actual)
  end

  test 'extract meta information from major detail link' do
    skip "Fix Grosse Anfragen later"
    detail_page = Nokogiri::HTML(File.read(Rails.root.join('test/fixtures/bw/detail_page_major.html')))
    link = @scraper.get_detail_link(detail_page)
    actual = @scraper.extract_from_originators(link.text)
    expected = {
      full_reference: '15/1608',
      doctype: Paper::DOCTYPE_MAJOR_INTERPELLATION,
      published_at: Date.parse('2012-04-25'),
      originators: { people: [], parties: ['FDP/DVP'] },
      answerers: { ministries: ['LReg'] }
    }
    assert_equal(expected, actual)
  end

  test 'extract title from Detail' do
    actual = @scraper.extract_detail_title(@detail_page)
    expected = 'Kennzeichnung von Streuobst und Streuobstprodukten aus Baden-Württemberg'
    assert_equal(expected, actual)
  end

  test 'extract complete paper from detail page' do
    actual = @scraper.extract_detail_paper(@detail_page)
    expected = {
      full_reference: '16/5196',
      legislative_term: '16',
      reference: '5196',
      doctype: Paper::DOCTYPE_MINOR_INTERPELLATION,
      title: 'Kennzeichnung von Streuobst und Streuobstprodukten aus Baden-Württemberg',
      url: 'https://www.landtag-bw.de/files/live/sites/LTBW/files/dokumente/WP16/Drucksachen/5000/16%5F5196%5FD.pdf',
      published_at: Date.parse('2018-11-15'),
      is_answer: true,
      originators: { people: ['Klaus Hoher'], parties: ['FDP/DVP'] },
      answerers: { ministries: ['Ministerium für Ländlichen Raum und Verbraucherschutz'] },
    }
    assert(expected <= actual)
  end
end
