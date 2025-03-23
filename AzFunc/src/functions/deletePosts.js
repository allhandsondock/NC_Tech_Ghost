const { app } = require('@azure/functions');
const GhostAdminAPI = require('@tryghost/admin-api');

// Initialize Ghost Admin API using environment variables
const api = new GhostAdminAPI({
    url: process.env.GHOST_URL,  // e.g., "https://yourghostblog.com"
    key: process.env.GHOST_ADMIN_API_KEY,  // Admin API Key from Ghost
    version: "v5.0"  // Ensure version matches your Ghost instance
});

app.http('deletePosts', {
    methods: ['GET', 'POST'],
    authLevel: 'admin',
    handler: async (request, context) => {
        context.log(`Http function processed request for url "${request.url}"`);
        
        try {
            //Fetch all posts
            const posts = await api.posts.browse({ limit: "all" });
            context.log(`posts"${posts.length}"`);
            if (posts.length === 0) {
                return { status: 200, body: "No posts found to delete." };
            }

            // Delete each post
            for (const post of posts) {
                await api.posts.delete({ id: post.id });
                context.log(`Deleted post: ${post.id}`);
            }

            return { status: 200, body: `Deleted ${posts.length} posts.` };
        } catch (error) {
            context.log.error("Error deleting posts:", error);
            return { status: 500, body: `Error: ${error.message}` };
        }
    }
});
