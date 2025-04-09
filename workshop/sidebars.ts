import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const sidebars: SidebarsConfig = {

  tutorialSidebar: [
    'welcome',
    {
      type: 'category',
      label: 'Define',
      items: [
        'define/prerequisites',
        'define/introduction'],
    },
    {
      type: 'category',
      label: 'Develop',
      items: [
        {
          type: 'category',
          label: 'Azure OpenAI',
          items: [
            'develop/azure-openai/rate-limit',
            'develop/azure-openai/track-consumption',
            'develop/azure-openai/dynamic-failover',],
        },
        {
          type: 'category',
          label: 'Agents',
          items: [
            'develop/agents/mcp'],
        },
        'develop/congratulations',
      ],
    },
  ],
};

export default sidebars;
