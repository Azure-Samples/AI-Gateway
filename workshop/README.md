# To run the workshop locally:-

- Navigate to `cd workshop`
- Install dependencies with `npm install`
- Start workshop with `npm start`

    This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.
- Build for production with `npm run build`

    This command generates static content into the `build` directory and can be served using any static contents hosting service.

- Test your production build locally with `npm run serve`

### Deployment

Using SSH:

```
$ USE_SSH=true npm run deploy
```

Not using SSH:

```
$ GIT_USER=<Your GitHub username> npm run deploy
```

This command is a convenient way to build the website and push to the `gh-pages` branch.