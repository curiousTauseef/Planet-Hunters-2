$ = window.jQuery
# jQuery.noConflict()  //REMEMBER ME!!!!!!

# language manager
t7e = require 't7e'
enUs = require './lib/en-us'
t7e.load enUs
LanguageManager = require 'zooniverse/lib/language-manager'
languageManager = new LanguageManager
  translations:
    en: label: 'English', strings: enUs
    # es: label: 'Español', strings: './dev-translations/es.json'
languageManager.on 'change-language', (e, code, strings) ->
  t7e.load strings
  t7e.refresh()

# api
Api = require 'zooniverse/lib/api'
api = new Api project: 'planet_hunter'

# site navigation
SiteNavigation = require './controllers/site-navigation'
siteNavigation = new SiteNavigation
siteNavigation.el.appendTo document.body

# router
StackOfPages = require 'stack-of-pages'
stack = new StackOfPages
  '#/'          : require './controllers/home-page'
  '#/about'     : require './controllers/about-page'
  '#/classify'  : require './controllers/classifier'
  '#/science'   : require './controllers/science-page'
  '#/profile'   : require './controllers/profile'
  '#/education' : require './controllers/education'
  '#/discuss'   : require './controllers/discuss'
  '#/blog'      : require './controllers/blog'
  "#/verify"    : require './controllers/verification'
  NOT_FOUND: '<div class="content-block"><div class="content-container"><h1>Page not found!</h1></div></div>'
  ERROR: '<div class="content-block"><div class="content-container"><h1>There was an error!</h1></div></div>'
document.body.appendChild stack.el

# top bar
TopBar = require 'zooniverse/controllers/top-bar'
topBar = new TopBar
topBar.el.appendTo document.body

browserDialog = require 'zooniverse/controllers/browser-dialog'
browserDialog.check msie: 9

# get user
User = require 'zooniverse/models/user'
u = User.fetch()

# footer
footerContainer = document.createElement 'div'
footerContainer.className = 'footer-container'
Footer = require 'zooniverse/controllers/footer'
footer = new Footer
document.body.appendChild footerContainer
footer.el.appendTo footerContainer

$("<div id='social-media'>
    <span>Zooniverse: The universe is too big to explore without you.</span>
    <div id='social-icons'>
      <a href='http://www.facebook.com'><img src='./images/social-media/facebook.svg'></a>
      <a href='http://www.googleplus.com'><img src='./images/social-media/googplus.svg'></a>
      <a href='http://www.twitter.com'><img src='./images/social-media/twit.svg'></a>
    </div>
  </div>").appendTo footerContainer

movePlanet = ->
  date = new Date
  # DEBUG CODE
  # console.log "movePlanet(): ", date.getHours(), ':', date.getMinutes(), ':', date.getSeconds()
  minuteFrac = ( date.getSeconds() / 60 )
  hourFrac   = ( date.getMinutes() / 60 )
  dayFrac    = ( date.getHours() / 24 )
  # DEBUG CODE
  # console.log 'minuteFrac = ', minuteFrac
  # console.log 'hourFrac   = ', hourFrac
  # console.log 'dayFrac    = ', dayFrac

  scaleFactor = dayFrac
  for planet in [$(".bg-planet")...]
    planet.style.top    = Math.round( scaleFactor * 100) + '%'
    planet.style.left   = Math.round( scaleFactor * 100) + '%'
    planet.style.width  = Math.round( scaleFactor * 2*530) + 'px'
    planet.style.height = Math.round( scaleFactor * 2*530) + 'px'

    # # DEBUG CODE
    # console.log '-------------------------------'
    # console.log 'planet.top: ',    planet.style.top
    # console.log 'planet.left: ',   planet.style.left
    # console.log 'planet.width: ',  planet.style.width
    # console.log 'planet.height: ', planet.style.height
  # setTimeout( movePlanet, 300000 ) # 5 min

movePlanet()

# bind app to window
window.app = {api, siteNavigation, stack, topBar}
module.exports = window.app
