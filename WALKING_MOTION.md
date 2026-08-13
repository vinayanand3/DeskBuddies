# Walking motion reference

DeskBuddies uses distinct eight-frame gait cycles rather than sharing one generic quadruped animation. The animation is intentionally readable at the pet's small desktop size, so the poses exaggerate limb separation while preserving each animal's footfall order and support pattern.

| Pet | Footfall order | Motion treatment |
| --- | --- | --- |
| Cat | Near hind, near fore, far hind, far fore | Four-beat lateral-sequence walk, quiet head, flexible shoulders, and hind paws tracking toward the same-side forepaw path. |
| Dog | Near hind, near fore, far hind, far fore | Stable single-foot lateral sequence with evenly spaced contacts, long stance phases, and visible elbow and hock flexion. |
| Sloth | Near hind, far fore, far hind, near fore | Slow high-duty-factor crawl, at least three supports, low belly, one short swing at a time, and minimal vertical motion. |
| Giant panda | Near hind, far fore, far hind, near fore | Heavy diagonal-sequence walk with short steps, alternating shoulder and hip roll, head counter-sway, full forepaw contact, and a subtly raised hind heel. |

Each eight-frame loop contains contact, weight acceptance, planted stance, push-off, flexed lift, and forward swing. Profile-specific playback cadence prevents the sloth and panda from moving with cat or dog timing.

## Research basis

- Cat footfall order and eight support phases: https://pmc.ncbi.nlm.nih.gov/articles/PMC4044364/
- Cat limb and paw trajectory: https://pmc.ncbi.nlm.nih.gov/articles/PMC4137248/
- Dog lateral-sequence walk: https://pmc.ncbi.nlm.nih.gov/articles/PMC4517757/
- Dog single-foot contact timing and stability: https://pubmed.ncbi.nlm.nih.gov/28264903/
- Three-toed sloth terrestrial crawling and propulsion: https://pubmed.ncbi.nlm.nih.gov/36747379/
- High-duty-factor slow walking: https://pmc.ncbi.nlm.nih.gov/articles/PMC5599235/
- Giant panda gait and foot posture: https://libsysdigi.library.uiuc.edu/OCA/Books2010-10/giantpandamorpho03davi/giantpandamorpho03davi.pdf
