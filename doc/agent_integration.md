# Agent guidance for apps using Liquid Prism

The reusable [Liquid Prism skill](../skills/liquid-prism/SKILL.md) teaches agents
how to compose adaptive screens, preserve native defaults and diagnose integration
issues before changing rendering. It is consumer guidance, separate from the
package's [maintainer instructions](agents/README.md).

## Install in a consuming project

Copy the **entire** `skills/liquid-prism` directory from a Liquid Prism checkout
into your app's `.agents/skills/liquid-prism` directory for agents that discover
project skills there. Keep `references/` with `SKILL.md`; the skill has no external
tool dependencies or links back to this checkout. For another agent, use its
supported project skill directory, or link the skill explicitly from its project
instructions.

For example, from your app's root, replacing the source path:

```sh
mkdir -p .agents/skills
cp -R /path/to/liquid_prism/skills/liquid-prism .agents/skills/
```

If the destination already exists, review and replace the existing skill folder
rather than nesting a second copy. Commit the copied skill with your app so all
contributors receive it. Refresh it deliberately when updating the dependency;
record the source tag or commit in your app's dependency-update notes. The skill
instructs agents to verify APIs against the resolved dependency, since guidance
from a newer checkout may describe behavior an older release does not support.

Add this routing hint to your app's agent instructions if skills are not selected
automatically:

> For Liquid Prism integration, customization or visual diagnosis, read
> `.agents/skills/liquid-prism/SKILL.md` and the relevant linked reference before
> editing. Verify APIs against the app's resolved Liquid Prism dependency.

You can also explicitly request `$liquid-prism` in agents supporting named skills.

## What it covers

- [Scaffold composition, inset ownership, pull to refresh and continuous scroll edges](../skills/liquid-prism/references/scaffolds.md)
- [Component defaults, control ownership and title motion](../skills/liquid-prism/references/components.md)
- [Layout and renderer verification](../skills/liquid-prism/references/verification.md)

The skill guides decisions rather than duplicating the API catalog. Use the
[component guide](components.md), [customization guide](customization.md) and
[style reference](style_reference.md) from the installed version for signatures
and available options. In particular, a permanently visible accessory and a
content row that scrolls before pinning require different composition choices.
