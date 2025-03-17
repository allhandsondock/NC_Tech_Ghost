module.exports = async function (context, myTimer) {
    // The admin API client is the easiest way to use the API
   const GhostAdminAPI = require('@tryghost/admin-api');

   // Configure the client
   const api = new GhostAdminAPI({
       url: process.env["GHOST_URL"],
       // Admin API key goes here
       key: process.env["GHOST_ADMIN_API_KEY"],
       version: 'v3'
   });

   // Get all posts
   const allPosts = await api.posts.browse({limit: 'all'});

   // Delete all posts
    allPosts.map((post) => {   
           api.posts.delete({id: post.id});
   });

   
};