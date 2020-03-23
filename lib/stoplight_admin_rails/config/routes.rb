StoplightAdminRails::Engine.routes.draw do
  root 'home#index'

  get  'index',     to: 'home#index'
  get  'stats',     to: 'home#stats'
  post 'lock',      to: 'home#do_lock'
  post 'unlock',    to: 'home#do_unlock'
  post 'green',     to: 'home#make_green'
  post 'red',       to: 'home#make_red'
  post 'green_all', to: 'home#make_green_all'
end
