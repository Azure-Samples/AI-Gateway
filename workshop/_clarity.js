console.log("Hello from clarity.js");

// rr8k8ukjc3

import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment';

if (ExecutionEnvironment.canUseDOM) {
    console.log("Clarity script is being loaded");
    const clarityProjectId = 'rr8k8ukjc3';

    // Initialize or extend the global `clarity` function to queue commands
    window.clarity = window.clarity || function() {
      (window.clarity.q = window.clarity.q || []).push(arguments);
    };
  
    // Create the script element for the Clarity tracking code
    const clarityScript = document.createElement('script');
    clarityScript.src = `https://www.clarity.ms/tag/${clarityProjectId}`;
    clarityScript.async = true;
    clarityScript.defer = true;
  
    // Insert the script into the head of the document
    document.head.appendChild(clarityScript);
}