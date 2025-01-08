# Snippets

We use snippets to reduce redundancy and improve maintainability. Snippets are references from the many Jupyter notebook files throughout our labs. They work by using [Python's _%load_ magic command](https://ipython.readthedocs.io/en/stable/interactive/magics.html#magic-load).

## Loaded Snippets

Jupyter notebooks will have Python code blocks similar to this one:

```python
# %load ../../shared/snippets/openai-api-requests.py

import time
from openai import AzureOpenAI

...
```

What you see here is an executed load as the command is now commented out after the code has been loaded immediately below it.

While this is generally very maintable, the loading is static, unlike a function reference, for example. That means that code may be stale. When you are editing Jupyter notebook files, it is advisable that you execute the load commands fresh and check for git changes.

## Updating a Loaded Snippet

1. In a Jupyter Notebook's Python code cell, remove everything below the `%load` command in line 1.
1. Uncomment the `%load` command. The cell should then look similar to this:

    ```python
    %load ../../shared/snippets/openai-api-requests.py
    ```

1. Press the _Play_ button in the code cell to execute the `%load` command.
1. Repeate these steps for all code blocks with `%load` commands in the current file.
1. Save the file.
1. Check git for any changes to the file.
1. Test the changes.
1. Check in the changes.
