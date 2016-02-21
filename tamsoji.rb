require 'sinatra'
require 'sinatra/reloader'

require 'typhoeus'
require 'nokogiri'
require 'sentimental'

@@cookie = "datr=UL7IVtBGDX5sEJqeKmN1qbXk; c_user=100011020305703; fr=0ngMhV2LGlgK4heIz.AWUPMTQYe9_qFcuS1ki4EH76ItU.BWyL5Z.6c.AAA.0.AWXTeQDY; xs=67%3A-GXmdvmrpz2I9g%3A2%3A1455996505%3A15729; csm=2; s=Aa4Ikun6IalSLg7C.BWyL5Z; pl=n; lu=Rg3y-Gil9xvNXBaDsazdqLvw; act=1455996516275%2F1; p=-2; presence=EDvF3EtimeF1455996621EuserFA21B11020305703A2EstateFDsb2F0Et2F_5b_5dElm2FnullEuct2F1455995905BEtrFA2loadA2EtwF2406646330EatF1455996620630G455996621690CEchFDp_5f1B11020305703F2CC; wd=1197x289"

def get_emoji score
	case score
	when -1.0..-0.5 then ':rage:'
	when -0.5..-0.2 then ':expressionless:'
	when -0.2..0.2 then ':neutral_face:'
	when 0.2..0.5 then ':slight_smile:'
	when 0.4..1.0 then ':grinning:'
	end
end

def get_tams_posts
	req = Typhoeus::Request.new(
		"https://m.facebook.com/groups/TAMS17/",
		headers: { Cookie: @@cookie }
	)
	req.run
	body = req.response.body
	doc = Nokogiri::HTML(body)
	text = doc.xpath('//div//p').to_s
	text.gsub(/<[^>]*>/, '&').split('&').reject do |post|
		post.empty? || post.size < 10
	end
end

Sentimental.load_defaults
analyzer = Sentimental.new

get '/' do
	@@average ||= 0
	@@happiest ||= ''
	@@saddest ||= ''
	@@rated_posts ||= []
	haml :index
end

get '/update' do
	posts = get_tams_posts
	@@rated_posts = posts.map do |post|
		[post, analyzer.get_score(post)]
	end

	@@saddest = @@rated_posts.min_by { |p| p[1] }
	@@happiest = @@rated_posts.max_by { |p| p[1] }
	@@average = @@rated_posts.map { |p| p[1] }.reduce(:+).to_f / @@rated_posts.size

	redirect to '/'
end

__END__

@@ layout
%html
	%link{href: "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css", rel: "stylesheet"}
	%link{href: "https://cdn.jsdelivr.net/emojione/2.1.0/assets/css/emojione.min.css", rel: "stylesheet"}
	%script{src: "https://code.jquery.com/jquery-2.2.0.min.js"}
	%script{src: "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"}
	%script{src: "https://cdn.jsdelivr.net/emojione/2.1.0/lib/js/emojione.min.js"}
	:javascript
		$(function(){
			$(".convert-emoji").each(function(){
				var original = $(this).html();
				var converted = emojione.toImage(original);
				$(this).html(converted);
			});
		});
	%div.container.convert-emoji{ style: "max-width: 600px;" }
		= yield

@@ index
%h1 TAMS happiness score: #{(@@average*100).round(0)}% #{get_emoji @@average}
%h4 Most positive post
= @@happiest[0]
= get_emoji @@happiest[1]
%h4 Most negative post
= @@saddest[0]
= get_emoji @@saddest[1]
%h4 All posts
- @@rated_posts.each do |(post, score)|
	%p
		= post
		= get_emoji score
%p
	%form{ action: '/update' }
		%input.btn.btn-default{ type: 'submit', value: 'Update' }
