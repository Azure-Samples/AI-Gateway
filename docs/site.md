The workshop website lives at https://aka.ms/ai-gateway/workshop

## Adding a workshop lesson

- Decide which section it should be in e.g *define* or *develop*, you might even need to choose a sub directory here, for example *develop/azure-openai*.
- Create a markdown file with your lesson content, for example *lesson.md*. 
- You can adjust the viewing order by placing a frontmatter instruction on top like so:

    ```markdown
    ---
    sidebar_position: 1
    ---
    ```

    The lower number, the higher priority, you may adjust other lessons frontmatter as each lesson is recommended to have a unique number to get the view order you intended.

- Try viewing the workshop locally (follow instructions in the next section for viewing it).

## To run the workshop locally:-

- Navigate to `cd workshop`
- Install dependencies with `npm install`
- Start workshop with `npm start`, this will render the workshop locally. 

## Build the Workshop site

To deploy to it you need to do the following:

In the main branch:


- In *docosaurus.config.ts*, change the field `baseUrl` to **/AI-Gateway/**, this is so routing works in production. While testing locally it should have value **/**.
- Change to workshop folder

    ```sh
    cd workshop
    ```

- Install dependencies for Docosaurus

   ```sh
   npm install
   ```

- Build a new site

    ```sh
    npm run build
    ```

    This creates a *build* sub folder.

- Copy the content of *build* folder to *docs* folder in the *gh-pages* branch

    - Copy content on *build* folder to somewhere.
    - Switch to gh-pages branch `git checkout gh-pages`
    - Copy *build* content to *docs*. (Clean content of *docs* first)
    - Commit changes.

    Wait for GitHub to rebuild site


