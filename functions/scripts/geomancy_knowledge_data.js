// Knowledge base for the 16 geomantic figures, grounded in the traditional
// correspondences (Agrippa / Greer lineage): planet, zodiac, element,
// favorability, and how each figure reads as Judge, Witness, and Reconciler,
// plus per-domain guidance. Seed into Firestore with
// `node scripts/seed_geomancy_knowledge.js` from the functions directory.

module.exports = [
  {
    figure: "Via",
    latin: "The Way",
    planet: "Moon",
    zodiac: "Cancer",
    element: "Water",
    favorability:
      "Neutral and restless: excellent wherever change, travel, or movement is wanted; weak wherever the wish is for things to stay as they are.",
    core:
      "Via is the road itself - every line of the figure is single, so everything is in motion and nothing is settled. It shows a situation that is actively changing shape: what was true last month is not quite true now. It clears out stagnation and carries the matter somewhere new, which is a blessing when the seeker wants out of a rut and a warning when they want permanence.",
    as_judge:
      "As Judge, Via answers: the situation will not stay as it is. If the question hopes for change, movement, or escape, this is a yes in motion. If the question hopes to hold something still, the verdict is that it will shift regardless.",
    as_witness:
      "As a Witness, Via is the current pulling the matter along - a change already underway beneath the surface, a departure, a route opening, restlessness in someone involved.",
    as_reconciler:
      "As Reconciler, Via teaches that the resolution comes through moving, not holding. The seeker is being carried through a passage, and the lesson is to travel light through it.",
    domains: {
      love:
        "The relationship is in transition - deepening, changing form, or moving between phases. Feelings are real but not yet fixed; the connection responds to motion, not to gripping tighter.",
      career:
        "Change of role, workplace, or direction. Favorable for job changes, relocations, and travel-linked work; unfavorable for questions about whether a current position will stay stable.",
      money:
        "Money flows through rather than pools - income arrives and leaves quickly. Good for cash in motion (sales, deals in progress), poor for holding and accumulating right now.",
      health:
        "Conditions tend to move and pass rather than settle in. Acute rather than chronic; recovery comes with movement and change of routine.",
      timing:
        "Fast. Via is one of the quickest figures - expect motion within days or weeks, not months.",
    },
  },
  {
    figure: "Populus",
    latin: "The People",
    planet: "Moon",
    zodiac: "Cancer",
    element: "Water",
    favorability:
      "Purely neutral - a mirror. It amplifies the energy around it: good in good company, difficult in difficult company, and takes the color of the other figures and circumstances.",
    core:
      "Populus is the crowd - every line doubled, passive, receptive, reflecting. It shows a matter shaped less by the seeker's own action and more by the people, moods, and momentum already surrounding it: family, friends, an audience, public opinion, the emotional weather of a group. Nothing here moves on its own; it gathers and reflects what is brought to it.",
    as_judge:
      "As Judge, Populus says the outcome follows the current already flowing - the matter goes the way the surrounding people and momentum are already leaning. The seeker's own push matters less than the tide they are standing in.",
    as_witness:
      "As a Witness, Populus is the influence of others: opinions of family or friends, the pull of a group, someone deciding by consensus, or a crowd of feelings the seeker is absorbing that are not entirely their own.",
    as_reconciler:
      "As Reconciler, Populus teaches discernment between being carried and choosing - the resolution comes when the seeker notices which voices around them are steering the matter and decides which ones deserve that power.",
    domains: {
      love:
        "Other people are inside this relationship - families, friends, exes, or public opinion shaping how the two people see each other. The bond mirrors what surrounds it; protect it from noisy rooms.",
      career:
        "Team dynamics, group decisions, reputation among colleagues. Success comes through reading the room and moving with allies rather than solo pushes.",
      money:
        "Finances tied to shared pots, family money, or market mood. Follows the general current - not a time for a lone contrarian bet.",
      health:
        "Health mirrors environment - stress or calm is being absorbed from the people around. Fluctuating symptoms that track mood and company.",
      timing:
        "Depends on external flow rather than a fixed clock; things ripen when the surrounding current turns, often on the rhythm of weeks.",
    },
  },
  {
    figure: "Fortuna Major",
    latin: "The Greater Fortune",
    planet: "Sun",
    zodiac: "Leo",
    element: "Fire",
    favorability:
      "One of the most favorable figures in the whole art: lasting success earned from within. Slow to start, but what it builds endures.",
    core:
      "Fortuna Major is victory through inner strength - the kind of success no one can hand over and no one can take away. It often begins with difficulty and then steadily overturns it, like sun breaking through late in the day. Where it appears, the seeker's own character, effort, and dignity are the winning force, and the result is durable rather than flashy.",
    as_judge:
      "As Judge, Fortuna Major is a firm yes, especially where the seeker keeps their own effort in the matter. The win may come slower than hoped, but it comes with weight and stays won.",
    as_witness:
      "As a Witness, Fortuna Major is deep backing: the seeker's real merit, an inner reserve of strength, or powerful quiet support that outlasts louder obstacles.",
    as_reconciler:
      "As Reconciler, Fortuna Major teaches that persistence is the resolution - the matter rewards steadiness, and the lesson is that the seeker already carries the strength the outcome requires.",
    domains: {
      love:
        "A solid, protective, durable bond - or the arrival of one. Love that grows sturdier under pressure rather than cracking. Strongly favorable for commitment questions.",
      career:
        "Promotion, recognition, and authority earned by real work. Excellent for long-term ambitions, leadership questions, and contests - the seeker wins on merit.",
      money:
        "Lasting gain: assets that appreciate, income that grows and holds. Favors patient building over quick plays.",
      health:
        "Strong constitution and real recovery - vitality returns and stays. One of the best figures for health questions.",
      timing:
        "Slow but certain. Think seasons, not days - and worth every bit of the wait.",
    },
  },
  {
    figure: "Fortuna Minor",
    latin: "The Lesser Fortune",
    planet: "Sun",
    zodiac: "Leo",
    element: "Fire",
    favorability:
      "Favorable but fleeting: quick success that arrives with outside help and does not linger. Excellent for fast matters, unreliable for permanent ones.",
    core:
      "Fortuna Minor is the sun near the horizon - bright, warm, and moving fast. It brings swift wins carried by luck, allies, timing, or borrowed influence rather than slow inner effort. The gift is speed; the catch is instability. Whatever it grants should be used or secured quickly, because this window is open now and will not stay open.",
    as_judge:
      "As Judge, Fortuna Minor answers yes - for now. The matter succeeds if it is acted on quickly and wrapped up while momentum lasts; delay is the only real enemy of this verdict.",
    as_witness:
      "As a Witness, Fortuna Minor is help from outside: a well-placed friend, a lucky break, someone else's influence briefly at the seeker's service.",
    as_reconciler:
      "As Reconciler, Fortuna Minor teaches the seeker to take the win without overstaying - the resolution favors those who act inside the window and don't mistake a fast tide for a permanent sea.",
    domains: {
      love:
        "Sparks that catch fast - sudden chemistry, a whirlwind phase. Genuinely promising, but the connection needs deliberate securing before the initial heat fades.",
      career:
        "Quick opportunities via connections and referrals: a fast offer, a short-lived opening, a door held open by someone else. Move promptly.",
      money:
        "Fast money - a windfall, a quick deal, timely help. Take profits early; this is not the figure of compounding wealth.",
      health:
        "Rapid improvement, especially with outside intervention - but watch for relapse if recovery is treated as finished too soon.",
      timing:
        "Swift - days to a few weeks. The earliest-moving of the strong figures.",
    },
  },
  {
    figure: "Conjunctio",
    latin: "The Conjunction",
    planet: "Mercury",
    zodiac: "Virgo",
    element: "Air",
    favorability:
      "Neutral in itself, warm in effect: favorable for anything about joining, meeting, agreement, or recovering what was lost; it takes on the character of what it connects.",
    core:
      "Conjunctio is the crossroads where two forces meet - two people, two offers, two halves of a matter finding each other. It rules contracts, reunions, negotiations, and the recovery of lost things. On its own it decides nothing; its whole power is in the joining, so the outcome depends on what is being connected and how honestly the two sides actually meet.",
    as_judge:
      "As Judge, Conjunctio answers that the matter resolves through connection - a meeting, a conversation, an agreement, or a reunion is the hinge the whole question turns on. Said plainly: yes, if the two sides come together; nothing moves while they stay apart.",
    as_witness:
      "As a Witness, Conjunctio is the link in play: a negotiation underway, a mutual friend carrying messages, an attraction pulling two paths toward a crossing point.",
    as_reconciler:
      "As Reconciler, Conjunctio teaches integration - the resolution comes from combining what the seeker has been keeping separate: two options, two sides of themselves, or two people who need one honest conversation.",
    domains: {
      love:
        "Meeting, reunion, or a relationship reaching a genuine point of contact. Traditionally favorable for marriage and reconciliation questions - the pull between two people is mutual here.",
      career:
        "Partnerships, contracts, interviews, and collaborations. The breakthrough comes through another person or a signed agreement, not solo effort.",
      money:
        "Money through deals and joint ventures; also the classic figure for recovering lost money or property.",
      health:
        "Recovery through the right combination - the right practitioner plus the right treatment. Seek connection, not isolation.",
      timing:
        "Medium; the matter completes when the parties actually meet - often tied to an arranged meeting, message, or appointment.",
    },
  },
  {
    figure: "Carcer",
    latin: "The Prison",
    planet: "Saturn",
    zodiac: "Capricorn",
    element: "Earth",
    favorability:
      "Unfavorable for most questions - delay, restriction, and binding - but genuinely favorable for questions of security, stability, and keeping something safely held.",
    core:
      "Carcer is the closed circle: walls, delays, obligations, and situations that hold the seeker in place. Whatever the matter is, it is bound for now - by rules, by fear, by another's grip, or by the seeker's own patterns. Yet the same walls that confine also protect and hold firm; Carcer is misery for escape questions and quiet strength for questions about keeping and defending.",
    as_judge:
      "As Judge, Carcer answers: not now. The matter is locked, delayed, or fenced in, and forcing it will not open it. If the question is about keeping something safe or a bond holding, the verdict flips - it holds firmly.",
    as_witness:
      "As a Witness, Carcer is the restraining force: an obligation, a fear, a controlling influence, red tape, or a wall someone has built that the matter keeps hitting.",
    as_reconciler:
      "As Reconciler, Carcer teaches patience and structure - the resolution comes when the seeker stops rattling the bars and starts working the lock: maturity, discipline, and time are the key.",
    domains: {
      love:
        "A bond that holds tightly - which reads as security or as suffocation depending on the question. Feelings of being stuck or fenced in; commitment in its heaviest form.",
      career:
        "A stuck role, slow bureaucracy, blocked promotion. Progress is delayed rather than denied; favorable only for questions about job security itself.",
      money:
        "Money is tied up - locked in obligations, debts, or assets that cannot move. Good for saving and protecting, bad for freeing up funds now.",
      health:
        "Chronic and lingering rather than acute; conditions that settle in and need long, disciplined management.",
      timing:
        "The slowest figure. Months, not weeks - and only after sustained, patient work.",
    },
  },
  {
    figure: "Tristitia",
    latin: "Sorrow",
    planet: "Saturn",
    zodiac: "Aquarius",
    element: "Earth",
    favorability:
      "Unfavorable in almost all questions - grief, heaviness, descent - except matters of building, land, property, and anything meant to be anchored deep and last long.",
    core:
      "Tristitia is the stake driven downward - a single point descending into the earth. It brings heaviness, disappointment, and grief, the low point of a matter where energy sinks. But the same downward drive is what anchors foundations: for buildings, land, and long-term structures it is one of the strongest figures there is. Sorrow and rootedness are the same motion here, pointed at different questions.",
    as_judge:
      "As Judge, Tristitia warns of disappointment in light or fast matters - the thing hoped for arrives heavier, later, or sadder than wished. For property, foundations, and anything meant to last decades, it is instead a deep and stable yes.",
    as_witness:
      "As a Witness, Tristitia is the weight in the room: old grief, pessimism, a depressive drag, or the residue of a past loss still pressing on the current question.",
    as_reconciler:
      "As Reconciler, Tristitia teaches that roots grow in the dark - the resolution asks the seeker to sit with the heaviness long enough to find what it is anchoring, because this low point is laying a foundation.",
    domains: {
      love:
        "A heavy heart - mourning a bond, carrying old hurt into a new question, or a relationship moving through its saddest chapter. Depth is available here, but joy is not the current note.",
      career:
        "A grind phase; motivation sinks. Genuinely favorable only for real estate, construction, agriculture, and long-horizon builds.",
      money:
        "Downward pressure - losses or heavy obligations. The exception is property and land, where this figure favors buying and holding.",
      health:
        "Low energy, low mood; watch mental health as much as the body. Recovery is slow and needs support.",
      timing:
        "Slow and descending; the matter bottoms out before it stabilizes. Expect months.",
    },
  },
  {
    figure: "Laetitia",
    latin: "Joy",
    planet: "Jupiter",
    zodiac: "Pisces",
    element: "Water",
    favorability:
      "Highly favorable for nearly every question - happiness, luck, and lift - with the one caution that its gifts move fast and favor lightness over permanence.",
    core:
      "Laetitia is the tower rising - a single point reaching upward, the exact inverse of sorrow. It is laughter, relief, celebration, luck arriving, the moment a heavy matter suddenly lightens. Whatever it touches, it lifts. Its energy is quick and buoyant rather than deep and slow, so it blesses beginnings, reunions, and good news generously, and asks the seeker simply to receive rather than distrust the lightness.",
    as_judge:
      "As Judge, Laetitia is a warm yes - the matter resolves in the seeker's favor and sooner than the mood around it suggests. Good news is genuinely on its way; the verdict smiles.",
    as_witness:
      "As a Witness, Laetitia is a rising force of optimism and help: a blessing in motion, a cheerful ally, relief already forming behind the scenes.",
    as_reconciler:
      "As Reconciler, Laetitia teaches lightness - the resolution comes when the seeker stops bracing for the worst and lets the matter be as good as it is actually becoming.",
    domains: {
      love:
        "Happiness in love - laughter returning to a bond, engagements, honeymoon energy, a connection that simply feels good. One of the best figures for romance.",
      career:
        "Recognition, good news, a win worth celebrating - an offer, praise, a project landing well.",
      money:
        "Fortunate flow: a gain, a gift, relief from a squeeze. Enjoy it, and skim some into safety while it's here.",
      health:
        "Recovery and lifted spirits - one of the best health figures; body and mood rise together.",
      timing:
        "Fast - joy does not dawdle. Days to a few weeks.",
    },
  },
  {
    figure: "Acquisitio",
    latin: "Gain",
    planet: "Jupiter",
    zodiac: "Sagittarius",
    element: "Fire",
    favorability:
      "Strongly favorable wherever gaining, growing, or obtaining is the wish; unfavorable only where the seeker wants to lose or be rid of something, because what Acquisitio holds, it keeps.",
    core:
      "Acquisitio is the open bag filling up - the figure of gain, increase, and things coming into the seeker's grasp. Money, opportunities, knowledge, allies: it gathers. Its nature is to draw in and hold on, which makes it superb for profit and growth questions and genuinely awkward for anything the seeker wants gone - debts, illnesses, and unwanted ties also tend to stick around under its influence.",
    as_judge:
      "As Judge, Acquisitio answers yes to gain: the seeker ends this matter with more than they started - more money, more standing, more of what was asked about. If the wish was to shed or escape something, the verdict warns it clings.",
    as_witness:
      "As a Witness, Acquisitio is appetite and accumulation in play: ambition driving the matter, a growing offer, or someone steadily collecting advantage in the background.",
    as_reconciler:
      "As Reconciler, Acquisitio teaches worthiness to receive - the resolution comes when the seeker claims what is arriving instead of deflecting it, and holds it with open-handed confidence rather than a clenched grip.",
    domains: {
      love:
        "A relationship gaining depth, commitment, and substance - more of each other, willingly. Watch only that healthy holding doesn't turn possessive.",
      career:
        "Growth: a raise, expansion, new clients, accumulating skill and reputation. One of the best figures for advancement questions.",
      money:
        "The money figure - profit, successful ventures, wealth building on itself. Favorable for investing and negotiating from strength.",
      health:
        "Vitality is strong, but conditions can linger - what the body holds, it holds. Persistence is needed to clear what has settled in.",
      timing:
        "Steady and cumulative - gains build over weeks and months rather than landing overnight.",
    },
  },
  {
    figure: "Amissio",
    latin: "Loss",
    planet: "Venus",
    zodiac: "Taurus",
    element: "Earth",
    favorability:
      "Unfavorable for keeping, holding, and profiting - things slip through the fingers - yet favorable for love freely given, and excellent wherever losing something is exactly what is wanted.",
    core:
      "Amissio is the bag turned upside down - what was held pours out. Money spent, chances missed, things slipping away. But loss is only misfortune when the seeker wanted to keep the thing: under Amissio, illnesses leave, debts discharge, bad ties dissolve, and the heart gives itself away freely - which is why this Venus figure has always been kind to love, where surrender is the whole point.",
    as_judge:
      "As Judge, Amissio answers that something leaves the matter - money, an option, a hold the seeker had. If the question was about release, escape, or love given without guarantees, the verdict is quietly favorable: the loss is the doorway.",
    as_witness:
      "As a Witness, Amissio is the leak: spending, drifting attention, an outflow of energy or feeling, or someone gradually letting go of their side of the matter.",
    as_reconciler:
      "As Reconciler, Amissio teaches release - the resolution comes through letting go of the version of this matter the seeker was gripping, so their hands are free for what actually fits them.",
    domains: {
      love:
        "Love given freely - falling, surrendering, being swept. Favorable for romance and new passion; unfavorable for questions about holding onto someone who is drifting.",
      career:
        "Risk of losing ground - an opportunity missed, a role slipping. Not the moment to gamble a stable position; it favors walking away from what drains.",
      money:
        "Outflow: losses, expenses, poor timing for investment. The one gift is discharge - debts and financial burdens can finally clear.",
      health:
        "Genuinely favorable - sickness departs, symptoms leave the body. The classic figure of illness losing its grip.",
      timing:
        "Quick - things slip away or resolve by leaving within days to weeks.",
    },
  },
  {
    figure: "Puer",
    latin: "The Boy",
    planet: "Mars",
    zodiac: "Aries",
    element: "Fire",
    favorability:
      "Unfavorable for matters needing patience, tact, or peace; favorable where boldness wins - love pursued courageously, competition, and anything that rewards a decisive strike.",
    core:
      "Puer is the young warrior with a drawn sword - raw courage, desire, impulsiveness, and fight. He charges where wiser figures would negotiate, which wrecks delicate situations and wins contested ones. Passion runs hot here: attraction, rivalry, anger, and nerve all sharpen. The matter calls for daring, and it will also punish recklessness - the sword cuts both ways.",
    as_judge:
      "As Judge, Puer answers: fortune favors the bold move here, but not the careless one. Yes to acting with courage and speed; expect friction, sparks, or a fight along the way, and win it by keeping the head while the blood is up.",
    as_witness:
      "As a Witness, Puer is hot energy in the matter: a passionate or impulsive man, a rivalry, desire pushing hard, or the seeker's own restless urge to just do the thing.",
    as_reconciler:
      "As Reconciler, Puer teaches courage tempered by aim - the resolution comes from channeling the heat into one decisive, well-aimed action instead of scattering it in skirmishes.",
    domains: {
      love:
        "Pursuit and intensity - bold declarations, magnetic attraction, and quick tempers in equal measure. Favorable for making the first move; stormy for questions about calm stability.",
      career:
        "Competition, bold pitches, going for the ambitious role. Favors the assertive play; unfavorable for delicate office politics.",
      money:
        "Aggressive moves can pay, but the risk is real - impulse spending and rash bets are the trap. Strike once, deliberately.",
      health:
        "Acute and sudden: fevers, injuries, inflammation. Energy is high; the caution is accidents and burnout, not weakness.",
      timing:
        "Sudden - the matter turns on a single fast moment, often within days.",
    },
  },
  {
    figure: "Puella",
    latin: "The Girl",
    planet: "Venus",
    zodiac: "Libra",
    element: "Air",
    favorability:
      "Favorable, especially in love, beauty, harmony, and social matters - with the caveat that her favor is changeable and does not by itself promise permanence.",
    core:
      "Puella is grace holding a mirror - charm, beauty, kindness, and the wish for harmony. She smooths conflict, draws people in, and blesses anything social or romantic. Her nature is genuinely warm but also changeable: she reflects the moment, and the moment can shift. What she grants is real sweetness now, which deepens into permanence only if something sturdier is built underneath it.",
    as_judge:
      "As Judge, Puella is a gentle yes - especially for matters of the heart, reconciliation, and anything needing goodwill. The verdict favors the seeker, with the soft warning that this harmony should be tended, not taken as guaranteed forever.",
    as_witness:
      "As a Witness, Puella is the charm in the matter: a kind or beautiful woman, an attraction, a diplomatic influence smoothing the way, or the seeker's own appeal working quietly for them.",
    as_reconciler:
      "As Reconciler, Puella teaches harmony as a practice - the resolution comes through grace, honest sweetness, and making peace attractive, rather than through force or argument.",
    domains: {
      love:
        "One of the warmest figures for romance - affection, courtship, being genuinely liked. Favorable for new love and reconciliation; keep tending it, since her mood mirrors what it receives.",
      career:
        "Favor and likability open doors - client charm, creative and aesthetic work, roles where relationships decide outcomes.",
      money:
        "Pleasant but fluctuating - money for beauty, comfort, and pleasure flows both ways. Fine for spending with taste, not a figure of hard accumulation.",
      health:
        "Mild and mending - gentle recovery, improved wellbeing, benefit from rest and pleasant surroundings.",
      timing:
        "Soon but fluid - the matter warms within weeks, with mood-dependent wobbles along the way.",
    },
  },
  {
    figure: "Albus",
    latin: "White",
    planet: "Mercury",
    zodiac: "Gemini",
    element: "Air",
    favorability:
      "Favorable for thought, planning, study, negotiation, and peace; a wise but physically weak figure - it wins by clarity, never by force.",
    core:
      "Albus is the white-haired sage, the upturned cup catching clear water - peace, wisdom, and a quiet mind. It favors everything done deliberately: analysis, contracts, study, counsel, honest conversation. Its strength is entirely mental and calm, so it steadies chaotic situations beautifully but has no muscle for confrontation; under Albus the matter is won on paper and in clear-headed talk, not in the arena.",
    as_judge:
      "As Judge, Albus answers yes to the considered path: the matter resolves well if approached with patience, clear thinking, and clean communication. Rushing or forcing it squanders a verdict that favors the calm mind.",
    as_witness:
      "As a Witness, Albus is the clear head in the matter: wise counsel, a thoughtful ally, a period of reflection, or truth quietly surfacing through honest words.",
    as_reconciler:
      "As Reconciler, Albus teaches clarity - the resolution arrives once the seeker sees the matter as it actually is, writes it down, says it plainly, and lets understanding do what pushing could not.",
    domains: {
      love:
        "A gentle, thoughtful bond - slow-burning affection built on conversation and understanding. Favorable for resolving misunderstandings; short on fireworks, long on peace.",
      career:
        "Analysis, planning, contracts, study, and strategy - excellent for negotiations, exams, and any work of the mind. Weak for power struggles.",
      money:
        "Careful, modest gain through planning and prudence. Favors budgeting, reviewing terms, and patient decisions over bold plays.",
      health:
        "Convalescence - steady, quiet healing. Rest, routine, and calm are the actual medicine here.",
      timing:
        "Slow and gentle - the matter clarifies over weeks; let it ripen rather than forcing a date.",
    },
  },
  {
    figure: "Rubeus",
    latin: "Red",
    planet: "Mars",
    zodiac: "Scorpio",
    element: "Water",
    favorability:
      "The most cautionary figure: passion, temper, excess, and hidden motives. Unfavorable for nearly all clean outcomes; its only favor is to raw passion and to burning away what deserved to burn.",
    core:
      "Rubeus is the overturned cup spilling red - passion past its banks. Temper, lust, addiction, deception, and hidden agendas live here; the matter carries more heat below the surface than anyone is admitting. Tradition treats it as the darkest figure in the art. Yet its honesty is exactly that: it exposes what the polite version of the story hides, and sometimes what it burns down needed burning.",
    as_judge:
      "As Judge, Rubeus is a warning verdict: the matter as currently framed is distorted by desire, anger, or something concealed, and a clean outcome needs the hidden element dragged into the light first. Proceed only with eyes fully open.",
    as_witness:
      "As a Witness, Rubeus is the fire under the floorboards: jealousy, temptation, a deceptive influence, someone's unspoken agenda, or the seeker's own passion arguing louder than their judgment.",
    as_reconciler:
      "As Reconciler, Rubeus teaches radical honesty about desire - the resolution comes when the seeker names what they actually want and what they're actually angry about, because the untold truth is what has been running the matter.",
    domains: {
      love:
        "Intense chemistry braided with jealousy, secrets, or obsession. The attraction is real and so is the distortion - demand full honesty before trusting the heat.",
      career:
        "Conflict, hidden agendas, office politics running hot. Guard reputation, document things, and don't sign anything in anger.",
      money:
        "High risk of being misled or of impulsive loss - scrutinize every deal and every motive, including the seeker's own.",
      health:
        "Inflammation, fevers, and the ways excess taxes the body - watch addictive patterns and burn-off-the-candle habits.",
      timing:
        "Eruptive and unpredictable - the matter breaks suddenly when the hidden pressure finally vents.",
    },
  },
  {
    figure: "Cauda Draconis",
    latin: "The Dragon's Tail",
    planet: "South Node of the Moon",
    zodiac: "Sagittarius",
    element: "Fire",
    favorability:
      "Unfavorable for beginnings and for holding on - it is the way out. Genuinely favorable only where an ending, an exit, or a clean break is exactly what is needed.",
    core:
      "Cauda Draconis is the threshold on the way out - the dragon's tail sweeping a chapter closed. Whatever it touches is finishing: a cycle completing, a door closing behind rather than opening ahead. It is harsh on new ventures and on anything the seeker hopes to keep, and quietly merciful in the same breath - it clears endings cleanly, burns bridges that led nowhere, and empties the room so something else can eventually be built.",
    as_judge:
      "As Judge, Cauda Draconis answers: this chapter ends. If the question was how to leave, quit, or close - the verdict favors the exit and favors making it clean. If the hope was to begin or preserve, the honest answer is that this particular form of the matter is completing.",
    as_witness:
      "As a Witness, Cauda Draconis is the pull of the past on its way out: something already leaving the situation, an old pattern exhausting itself, or a person halfway through the door.",
    as_reconciler:
      "As Reconciler, Cauda Draconis teaches clean closure - the resolution asks the seeker to finish the ending properly, keep the lesson, and leave the rest, because the space being cleared is the actual gift.",
    domains: {
      love:
        "A relationship or a phase of it completing - either a true parting, or an old skin the bond must shed to survive. Not the figure for starting a new romance.",
      career:
        "Exits: resignation, the end of a project or contract, closing a business chapter. Favorable for leaving well; poor for launching.",
      money:
        "The tail end of a financial cycle - settle accounts, close positions, stop feeding what is finished. Not a moment for new ventures.",
      health:
        "A crisis passing out of the system - the end of an illness phase, though it leaves the seeker drained and in need of true rest.",
      timing:
        "Soon, at the natural end of the current cycle - endings under this figure do not drag once accepted.",
    },
  },
  {
    figure: "Caput Draconis",
    latin: "The Dragon's Head",
    planet: "North Node of the Moon",
    zodiac: "Virgo",
    element: "Earth",
    favorability:
      "Favorable for beginnings, growth, and entering - a doorway inward. Neutral-to-slow for everything already underway; its gifts start small and compound.",
    core:
      "Caput Draconis is the threshold on the way in - the dragon's head at an open doorway. It blesses starts: new ventures, new bonds, first steps, fresh ground. Its nature is upward and entering, but young - what begins under it arrives as a seed rather than a harvest, gathering strength as it grows. It asks commitment at the threshold and repays it with a beginning that has real roots.",
    as_judge:
      "As Judge, Caput Draconis answers yes to beginning: enter, start, plant, commit. The full result matures over time, but the doorway is genuinely open now and favors those who step through deliberately.",
    as_witness:
      "As a Witness, Caput Draconis is fresh force arriving in the matter: a new person, new support, a first-time opportunity, or the seeker's own renewed appetite for a fresh start.",
    as_reconciler:
      "As Reconciler, Caput Draconis teaches commitment to beginnings - the resolution comes from treating this as day one and building accordingly, instead of grieving the old version of the matter.",
    domains: {
      love:
        "A new relationship, or a genuinely new phase of an existing one - fresh terms, fresh honesty, a bond replanted. Favorable for questions about starting.",
      career:
        "New roles, launches, ventures, and studies - excellent for starting; give the seed time before judging the tree.",
      money:
        "Early-stage growth: new income streams and investments that build gradually. Favorable entry point, modest immediate returns.",
      health:
        "Recovery begins - the turn toward improvement is here, gathering strength week by week.",
      timing:
        "The beginning is immediate; the fruit takes its season. Expect the first signs quickly and the full result over months.",
    },
  },
];
