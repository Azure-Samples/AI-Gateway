import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<'svg'>>;
  description: ReactNode;
  url: string;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Model Context Protocol (MCP)',
    Svg: require('@site/static/img/logo.svg').default,
    description: (
      <>
        Use MCP in Azure API Management for seamless LLM tool integration, leveraging OAuth 2.0 for robust authentication and authorization.
      </>
    ),
    url: '/docs/agents/mcp',
  },
  {
    title: 'OpenAI Agents',
    Svg: require('@site/static/img/openai.svg').default,
    description: (
      <>
        Integrate OpenAI Agents with Azure OpenAI models and API-based tools, managed through Azure API Management.
      </>
    ),
    url: '/docs/agents/openai-agents',
  },
  {
    title: 'AI Agent Service',
    Svg: require('@site/static/img/agent-service.svg').default,
    description: (
      <>
        Integrate Azure AI Agent Service with Azure OpenAI models, Logic Apps, and OpenAPI-based APIs using Azure API Management.
      </>
    ),
    url: '/docs/agents/ai-agent-service',
  },
  {
    title: 'Function Calling',
    Svg: require('@site/static/img/function-calling.svg').default,
    description: (
      <>
        Utilize Azure API Management to manage OpenAI function calling with an Azure Functions API for streamlined and efficient operations.
      </>
    ),
    url: '/docs/azure-openai/function-calling',
  },
  {
    title: 'Access Controlling',
    Svg: require('@site/static/img/access-control.svg').default,
    description: (
      <>
        Enable authorized access to OpenAPI APIs with OAuth 2.0 via an identity provider, managed through Azure API Management.
      </>
    ),
    url: '/docs/azure-openai/access-controlling',
  },
  {
    title: 'Token Rate Limiting',
    Svg: require('@site/static/img/rate-limit.svg').default,
    description: (
      <>
        Control API traffic by enforcing usage limits and optimize resource allocation with rate limiting policies in Azure API Management.
      </>
    ),
    url: '/docs/azure-openai/rate-limit',
  },
  {
    title: 'Analytics & Monitoring',
    Svg: require('@site/static/img/analytics.svg').default,
    description: (
      <>
        Gain insights into model token consumption for usage patterns with Application Insights and emit token metric policy.
      </>
    ),
    url: '/docs/azure-openai/track-consumption',
  },
  {
    title: 'Semantic Caching',
    Svg: require('@site/static/img/semantic-cache.svg').default,
    description: (
      <>
        Reduce latency and costs with caching strategies in Azure API Management, based on vector proximity and similarity score thresholds.
      </>
    ),
    url: '/docs/azure-openai/semantic-caching',
  },
  {
    title: 'Dynamic Failover',
    Svg: require('@site/static/img/load-balancing.svg').default,
    description: (
      <>
        Utilize Azure API Management's built-in load balancing functionality to manage Azure OpenAI endpoints or mock servers efficiently.
      </>
    ),
    url: '/docs/azure-openai/dynamic-failover',
  },
  {
    title: 'FinOps Framework',
    Svg: require('@site/static/img/finops.svg').default,
    description: (
      <>
        Control AI costs with Azure API Management and the FinOps Framework, enabling automated subscription disabling via Azure Monitor/ Logic Apps.
      </>
    ),
    url: '/docs/introduction',
  },
  {
    title: 'SLM Self-hosting',
    Svg: require('@site/static/img/phi.svg').default,
    description: (
      <>
       Utilize the self-hosted Phi-3 (SLM) through Azure API Management's self-hosted gateway with OpenAI API compatibility for efficient integration.
      </>
    ),
    url: '/docs/introduction',
  },
  {
    title: 'AI Foundry Deepseek',
    Svg: require('@site/static/img/deepseek.svg').default,
    description: (
      <>
        Utilize the Deepseek R1 model via Azure AI Foundry, employing the Azure AI Model Inference API and APIM policies.
      </>
    ),
    url: '/docs/introduction',
  },
];

function Feature({title, Svg, description, url}: FeatureItem) {
  return (
    
    <div className={clsx('col col--3')}>
        <div className="text--center">
           <a title="go to lab" href={url}>
            <Svg className={styles.featureSvg} role="img" />
          </a>
        </div>
        <div className="text--center padding-horiz--md">
          <Heading as="h3">{title}</Heading>
          <p>{description}</p>
        </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}