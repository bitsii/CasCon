// Init F7 Vue Plugin
Framework7.use(Framework7Vue);

// Init Page Components
Vue.component('page-settings', {
  template: '#page-settings'
});
Vue.component('page-wifi', {
  template: '#page-wifi'
});
Vue.component('page-device', {
  template: '#page-device'
});
Vue.component('page-discover', {
  template: '#page-discover'
});
Vue.component('page-inform', {
  template: '#page-inform'
});
Vue.component('page-dynamic-routing', {
  template: '#page-dynamic-routing'
});
Vue.component('page-not-found', {
  template: '#page-not-found'
});

// Init App
new Vue({
  el: '#app',
  data: function () {
    return {
      // Framework7 parameters here
      f7params: {
        root: '#app', // App root element
        id: 'io.framework7.testapp', // App bundle ID
        name: 'Framework7', // App name
        theme: 'auto', // Automatic theme detection
        // App routes
        routes: [
          {
            path: '/settings/',
            component: 'page-settings'
          },
          {
            path: '/discover/',
            component: 'page-discover'
          },
          {
            path: '/inform/',
            component: 'page-inform'
          },
          {
            path: '/dynamic-route/blog/:blogId/post/:postId/',
            component: 'page-dynamic-routing'
          },
          {
            path: '(.*)',
            component: 'page-not-found',
          },
        ],
      }
    }
  },
});
