import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'APIM ❤️ OpenAI  Workshop',
  tagline: 'Conceptual introduction of GenAI Gateway capabilities in Azure API Management',
  favicon: 'img/logo.svg',
  url: 'https://Azure-Samples.github.io',
  baseUrl: '/',
  organizationName: 'Azure-Samples',
  projectName: 'AI-Gateway',
  deploymentBranch: 'gh-pages',
  trailingSlash: false,
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          path: 'docs',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/ai-gateway.gif',
    navbar: {
      title: 'AI Gateway',
      logo: {
        alt: 'My Site Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Workshop',
        },
        {
          href: 'https://github.com/Azure-Samples/AI-Gateway',
          label: 'GitHub',
          position: 'left',
        },
        {
          href: 'https://www.youtube.com/playlist?list=PLI7iePan8aH4h7nHBlKLWZ8Mp2iiLKu34',
          label: 'YouTube',
          position: 'left',
        },
      ],
    },
    footer: {
      style: 'dark',
      logo: {
        alt: "API Management Logo",
        src: "img/gbb.png",
        href: "https://azure.microsoft.com/products/api-management",
        width: 100,
      },
      copyright: `Copyright © ${new Date().getFullYear()} Microsoft - Made with ♥️ by GBB & JavaScript Advocacy`,
      links: [],
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
