param(
    [string]$OutputPath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$script:Questions = @()
$script:Labels = @{}
$script:TotalQuestions = 41
$script:CurrentQuestion = 0

function O {
    param([string]$Value, [string]$Label, [string]$Example = "")
    $option = @{ value = $Value; label = $Label }
    if (-not [string]::IsNullOrWhiteSpace($Example)) {
        $option.example = $Example
    }
    return $option
}

function Register-Labels {
    param([array]$Options)
    foreach ($option in $Options) {
        $script:Labels[$option.value] = $option.label
    }
}

function Add-Question {
    param([string]$Id, [string]$Label, [string]$Type, [array]$Options = @(), [bool]$Required = $true, [string]$Example = "")
    $optionObjects = @()
    foreach ($option in $Options) {
        $entry = [ordered]@{
            value = $option.value
            label = $option.label
        }
        if ($option.ContainsKey("example") -and -not [string]::IsNullOrWhiteSpace($option.example)) {
            $entry.description = $option.example
        }
        $optionObjects += [pscustomobject]$entry
    }
    $question = [ordered]@{
        id = $Id
        label = $Label
        type = $Type
        options = $optionObjects
        required = $Required
    }
    if (-not [string]::IsNullOrWhiteSpace($Example)) {
        $question.example = $Example
    }
    $script:Questions += [pscustomobject]$question
}

function Label-Of {
    param([string]$Value)
    if ($script:Labels.ContainsKey($Value)) { return $script:Labels[$Value] }
    if ([string]::IsNullOrWhiteSpace($Value)) { return "Not specified" }
    return $Value
}

function Join-Labels {
    param([object]$Values)
    $items = @(@($Values) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return "None specified" }
    return (($items | ForEach-Object { Label-Of ([string]$_) }) -join ", ")
}

function Bullet-List {
    param([object]$Values, [bool]$UseLabels = $true)
    $items = @(@($Values) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return "- None specified" }
    if ($UseLabels) {
        return (($items | ForEach-Object { "- $(Label-Of ([string]$_))" }) -join "`r`n")
    }
    return (($items | ForEach-Object { "- $_" }) -join "`r`n")
}

function To-List {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    return @($Text -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Unique {
    param([object]$Values)
    return @(@($Values) | Where-Object { $_ } | Select-Object -Unique)
}

function Get-SafeFileName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "Anonymous Persona"
    }

    $invalidChars = [Regex]::Escape((-join [System.IO.Path]::GetInvalidFileNameChars()))
    $safeName = [Regex]::Replace($Name, "[$invalidChars]", "")
    $safeName = ($safeName -replace "\s+", " ").Trim()

    if ([string]::IsNullOrWhiteSpace($safeName)) {
        return "Anonymous Persona"
    }

    return $safeName
}

function Show-Intro {
    $banner = @'
 ____  _____ ____  ____   ___  _   _    _    _     ___ _____ ___ __  __
|  _ \| ____|  _ \/ ___| / _ \| \ | |  / \  | |   |_ _|_   _|_ _|\ \/ /
| |_) |  _| | |_) \___ \| | | |  \| | / _ \ | |    | |  | |  | |  \  /
|  __/| |___|  _ < ___) | |_| | |\  |/ ___ \| |___ | |  | |  | |  /  \
|_|   |_____|_| \_\____/ \___/|_| \_/_/   \_\_____|___| |_| |___|/_/\_\
'@

    Write-Host ""
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "__________________________________________________________________" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "                    By Gianluca Rabuazzo" -ForegroundColor Yellow
    Write-Host "__________________________________________________________________" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "PERSONALITIX Persona Builder" -ForegroundColor Magenta
    Write-Host "This 5-minute survey turns your answers into a timestamped Persona.md file." -ForegroundColor Green
    Write-Host "It builds a ready-to-use system prompt, communication rules, and a normalized persona config." -ForegroundColor White
    Write-Host ""
    Write-Host "You will answer $script:TotalQuestions short questions." -ForegroundColor Cyan
    Write-Host "Press Enter to accept a default. For multi-select questions, use commas like 1,3,4." -ForegroundColor DarkGray
}

function Start-Question {
    $script:CurrentQuestion += 1
    $remaining = [Math]::Max($script:TotalQuestions - $script:CurrentQuestion, 0)
    return [pscustomobject]@{
        Number = $script:CurrentQuestion
        Remaining = $remaining
    }
}

function Write-QuestionHeader {
    param([object]$Progress, [string]$Question)
    Write-Host ""
    Write-Host ("Question {0} of {1} | {2} remaining" -f $Progress.Number, $script:TotalQuestions, $Progress.Remaining) -ForegroundColor Cyan
    Write-Host $Question -ForegroundColor White
}

function Write-QuestionExample {
    param([string]$Example)
    if (-not [string]::IsNullOrWhiteSpace($Example)) {
        Write-Host ("Example: {0}" -f $Example) -ForegroundColor DarkGray
    }
}

function Has-OptionExamples {
    param([array]$Options)
    foreach ($option in $Options) {
        if ($option.ContainsKey("example") -and -not [string]::IsNullOrWhiteSpace($option.example)) {
            return $true
        }
    }
    return $false
}

function Write-ChoiceOption {
    param([int]$Number, [object]$Option)
    Write-Host ("  {0}. {1}" -f $Number, $Option.label)
    if ($Option.ContainsKey("example") -and -not [string]::IsNullOrWhiteSpace($Option.example)) {
        Write-Host ("     Example: ""{0}""" -f $Option.example) -ForegroundColor DarkGray
    }
}

function Ask-Text {
    param([string]$Id, [string]$Question, [string]$Default = "", [bool]$Required = $true, [string]$Example = "")
    Add-Question $Id $Question "free_text" @() $Required $Example
    $progress = Start-Question
    while ($true) {
        Write-QuestionHeader $progress $Question
        Write-QuestionExample $Example
        if ($Default) { $answer = Read-Host "Answer [$Default]" } else { $answer = Read-Host "Answer" }
        if ([string]::IsNullOrWhiteSpace($answer)) {
            if ($Default) { return $Default }
            if (-not $Required) { return "" }
        }
        else {
            return $answer.Trim()
        }
        Write-Host "Please enter a value." -ForegroundColor Yellow
    }
}

function Ask-One {
    param([string]$Id, [string]$Question, [array]$Options, [int]$Default = 1, [string]$Example = "")
    Register-Labels $Options
    Add-Question $Id $Question "single_select" $Options $true $Example
    $progress = Start-Question
    while ($true) {
        Write-QuestionHeader $progress $Question
        Write-QuestionExample $Example
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-ChoiceOption ($i + 1) $Options[$i]
        }
        $prompt = "Choose one"
        if (Has-OptionExamples $Options) { $prompt = "Choose the closest sentence/option" }
        $raw = Read-Host "$prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($raw)) { return $Options[$Default - 1].value }
        $selected = 0
        if ([int]::TryParse($raw, [ref]$selected) -and $selected -ge 1 -and $selected -le $Options.Count) {
            return $Options[$selected - 1].value
        }
        Write-Host "Please enter a number from the list." -ForegroundColor Yellow
    }
}

function Ask-Many {
    param([string]$Id, [string]$Question, [array]$Options, [string[]]$Defaults = @(), [bool]$Required = $true, [string]$Example = "")
    Register-Labels $Options
    Add-Question $Id $Question "multi_select" $Options $Required $Example
    $progress = Start-Question
    while ($true) {
        Write-QuestionHeader $progress $Question
        Write-QuestionExample $Example
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-ChoiceOption ($i + 1) $Options[$i]
        }

        $defaultNumbers = @()
        foreach ($defaultValue in $Defaults) {
            for ($i = 0; $i -lt $Options.Count; $i++) {
                if ($Options[$i].value -eq $defaultValue) { $defaultNumbers += ($i + 1) }
            }
        }

        $prompt = "Choose one or more, separated by commas"
        if (Has-OptionExamples $Options) { $prompt = "Choose the closest sentences/options, separated by commas" }
        if ($defaultNumbers.Count -gt 0) { $prompt += " [$($defaultNumbers -join ',')]" }
        $raw = Read-Host $prompt

        if ([string]::IsNullOrWhiteSpace($raw)) {
            if ($Defaults.Count -gt 0) { return @($Defaults) }
            if (-not $Required) { return @() }
        }
        elseif ($raw.Trim().ToLowerInvariant() -eq "all") {
            return @($Options | ForEach-Object { $_.value })
        }
        elseif (($raw.Trim().ToLowerInvariant() -eq "none") -and (-not $Required)) {
            return @()
        }
        else {
            $values = @()
            $valid = $true
            foreach ($part in @($raw -split "[,\s]+" | Where-Object { $_ })) {
                $selected = 0
                if (-not [int]::TryParse($part, [ref]$selected) -or $selected -lt 1 -or $selected -gt $Options.Count) {
                    $valid = $false
                    break
                }
                $value = $Options[$selected - 1].value
                if ($values -notcontains $value) { $values += $value }
            }
            if ($valid -and ($values.Count -gt 0 -or -not $Required)) { return @($values) }
        }
        Write-Host "Please enter numbers from the list, like 1,3,4." -ForegroundColor Yellow
    }
}

$englishOptions = @(O "basic" "Basic" "Please make this simpler."; O "intermediate" "Intermediate" "I understand, but please polish it."; O "good" "Good" "Make it clearer and more natural."; O "advanced" "Advanced" "Keep it professional and nuanced."; O "near_native" "Near-native" "Preserve subtle tone and rhythm.")
$culturalOptions = @(O "retain_native_style" "Retain native style" "Keep my direct natural style."; O "neutral_international" "Neutral international" "Make it globally neutral."; O "hybrid" "Hybrid" "Keep my voice, but polish it.")
$audienceOptions = @(O "clients" "Clients"; O "internal_peers" "Internal peers"; O "managers" "Managers"; O "executives" "Executives"; O "cross_functional" "Cross-functional partners"; O "vendors" "Vendors"; O "mixed" "Mixed")
$seniorityOptions = @(O "individual_contributor" "Individual contributor"; O "manager" "Manager"; O "senior_manager" "Senior manager"; O "director" "Director"; O "vp" "VP"; O "svp" "SVP"; O "c_suite" "C-suite"; O "mixed" "Mixed")
$useCaseOptions = @(O "email" "Email"; O "chat" "Chat"; O "meeting_notes" "Meeting notes"; O "executive_summary" "Executive summaries"; O "status_update" "Status updates"; O "escalation" "Escalations"; O "follow_up" "Follow-ups"; O "analysis_request" "Analysis requests"; O "decision_support" "Decision support")
$toneOptions = @(O "friendly" "Friendly" "Happy to help with this."; O "warm" "Warm" "I appreciate you taking a look."; O "direct" "Direct" "Please send this by Friday."; O "efficient" "Efficient" "Decision needed by 3 PM."; O "polished" "Polished" "Sharing a concise update below."; O "professional" "Professional" "Please find the next steps below."; O "casual" "Casual" "Quick note on this."; O "assertive" "Assertive" "I recommend we move forward."; O "collaborative" "Collaborative" "Let's align on the next step."; O "thoughtful" "Thoughtful" "I see two tradeoffs here."; O "confident" "Confident" "The best path is option A."; O "diplomatic" "Diplomatic" "I suggest we adjust the approach.")
$brevityOptions = @(O "concise" "Concise" "Done. I will send it by 3 PM."; O "balanced" "Balanced" "I can send it by 3 PM and flag any blockers."; O "detailed" "Detailed" "Here is the context, current status, risks, and next step.")
$directnessOptions = @(O "very_direct" "Very direct" "Please send this today."; O "balanced" "Balanced" "Could you send this today so we can close it?"; O "indirect" "Indirect" "It would be helpful to receive this today."; O "diplomatically_indirect" "Diplomatically indirect" "When possible, could you share this today so we stay on track?")
$expressivenessOptions = @(O "neutral" "Neutral" "Thanks, noted."; O "slightly_expressive" "Slightly expressive" "Thanks, that helps."; O "expressive" "Expressive" "Thanks, this is really helpful.")
$formalityOptions = @(O "low" "Low" "Quick update for you."; O "medium" "Medium" "Sharing a quick update."; O "medium_high" "Medium-high" "Please see the update below."; O "high" "High" "I am writing to provide the following update.")
$relationshipOptions = @(O "efficiency_first" "Efficiency first" "Decision needed today."; O "relationship_first" "Relationship first" "Thanks for your help on this."; O "balanced" "Balanced" "Thanks, and the decision needed is below."; O "efficiency_then_relationship" "Efficiency, then relationship" "Decision needed today. Thanks for jumping on it.")
$sentenceFlowOptions = @(O "short_sharp" "Short and sharp" "Blocked. Need approval today."; O "slightly_flowing" "Slightly flowing" "We are blocked and need approval today."; O "flowing" "Flowing" "We are currently blocked, so approval today would keep us moving."; O "context_dependent" "Context-dependent" "Use short updates, but add context for sensitive topics.")
$structureOptions = @(O "paragraphs" "Paragraphs" "One short paragraph with the key point."; O "bullets" "Bullets" "Status, risk, next step."; O "mixed" "Mixed" "Short intro, then bullets.")
$decisionOptions = @(O "make_clear_decisions" "Make clear decisions" "I recommend option A."; O "offer_options" "Offer options" "We can do A or B."; O "ask_questions_first" "Ask questions first" "What deadline should I optimize for?")
$feedbackOptions = @(O "direct_correction" "Direct correction" "Change this sentence to be clearer."; O "suggestion_based" "Suggestion-based" "I suggest making this more direct."; O "question_based" "Question-based" "Would it help to lead with the ask?")
$softeningOptions = @(O "direct" "Direct" "This needs to change."; O "moderate" "Moderate" "I suggest changing this."; O "highly_softened" "Highly softened" "It may be worth considering a small change.")
$greetingOptions = @(O "always_include" "Always include" "Hi Anna,"; O "usually_include" "Usually include" "Hi Anna,"; O "minimal" "Minimal" "Anna,")
$signoffFrequencyOptions = @(O "always_include" "Always include" "Best,"; O "usually_include" "Usually include" "Thanks,"; O "minimal" "Minimal" "No signoff unless needed.")
$emojiOptions = @(O "never" "Never" "Thanks."; O "rarely" "Rarely" "Thanks, that helps."; O "sometimes" "Sometimes" "Thanks, that helps."; O "often" "Often" "Thanks, that helps!")
$collaborationOptions = @(O "ask_before_finalize" "Ask before finalizing important work" "Before I finalize, should this be more direct?"; O "refine_iteratively" "Refine iteratively" "I will draft, then tighten it."; O "challenge_when_needed" "Challenge when needed" "This may create risk; I suggest a different path.")
$tendencyOptions = @(O "keep" "Keep" "Keep this part of my voice."; O "reduce" "Reduce" "Use it, but make it lighter."; O "remove" "Remove" "Cut it from the final version.")
$negativeOptions = @(O "too_corporate" "Too corporate" "I hope this message finds you well."; O "too_long" "Too long" "Here are all the details before the point."; O "too_cold" "Too cold" "Send it by Friday."; O "robotic" "Robotic" "Per your request, I am providing information."; O "too_casual" "Too casual" "Hey, just tossing this over."; O "vague" "Vague" "Let's circle back later."; O "overly_formal" "Overly formal" "I hereby submit the following."; O "overly_soft" "Overly soft" "Maybe, if you possibly can."; O "overly_emotional" "Overly emotional" "I am really worried about this."; O "passive" "Passive" "It was decided that this should happen.")
$impressionOptions = @(O "competence" "Competence" "The recommendation is clear."; O "clarity" "Clarity" "The ask is due Friday."; O "confidence" "Confidence" "I recommend option A."; O "collaboration" "Collaboration" "Let's align on the next step."; O "warmth" "Warmth" "Thanks for your help on this."; O "credibility" "Credibility" "Based on the data, option A is stronger."; O "executive_readiness" "Executive readiness" "Decision, risk, and next step are below.")

Show-Intro

$personaName = Ask-Text "persona_name" "What should this persona be called? Leave blank for Anonymous Persona." "" $false -Example "Gosia Work Voice"
if ([string]::IsNullOrWhiteSpace($personaName)) {
    $personaName = "Anonymous Persona"
}
$nativeLanguage = Ask-Text "native_language" "What is your native language?" "" $true -Example "Polish"
$englishProficiency = Ask-One "english_proficiency" "How would you describe your English proficiency?" $englishOptions 4 -Example "Pick the sentence closest to how much language support you want."
$culturalStyle = Ask-One "cultural_style" "How much of your native communication style should remain?" $culturalOptions 3 -Example "Pick the sentence closest to how your voice should feel."
$company = Ask-Text "company" "Company or organization name? Leave blank if you do not want it included." "" $false -Example "Contoso"
$industry = Ask-Text "industry" "What industry or domain is this persona for?" "Technology" $true -Example "Technology, banking, healthcare, consulting"
$department = Ask-Text "department" "Department or team? Leave blank if not relevant." "" $false -Example "Product Operations"
$roleTitle = Ask-Text "role_title" "What is your role title?" "Professional" $true -Example "Senior Project Manager"
$functionArea = Ask-Text "function_area" "What is your function area? Example: Operations, Engineering, Product." "" $false -Example "Operations"
$seniorityBand = Ask-One "seniority_band" "What seniority band should the persona reflect?" $seniorityOptions 1 -Example "Choose the level that best matches how senior the voice should sound."
$audienceTypes = Ask-Many "audience_types" "Who does this persona usually communicate with?" $audienceOptions @("internal_peers", "managers", "cross_functional") $true -Example "Internal peers, managers, and cross-functional partners."
$primaryUseCases = Ask-Many "primary_use_cases" "What should this persona mostly help with?" $useCaseOptions @("email", "chat", "status_update", "follow_up", "decision_support") $true -Example "Email, chat, status updates, and decision support."
$backgroundSummary = Ask-Text "background_summary" "Add a short background summary. Leave blank to skip." "" $false -Example "Experienced operator working across teams, focused on clarity and follow-through."

$coreToneTraits = Ask-Many "core_tone_traits" "Which tone traits should define the persona?" $toneOptions @("friendly", "direct", "professional", "collaborative", "confident") $true -Example "Pick the short sentences that sound most like you."
$brevityLevel = Ask-One "brevity_level" "How brief should the persona be?" $brevityOptions 2 -Example "Pick the sentence length that feels closest."
$directnessLevel = Ask-One "directness_level" "How direct should the persona be?" $directnessOptions 2 -Example "Pick the sentence you would be most comfortable sending."
$expressivenessLevel = Ask-One "expressiveness_level" "How expressive should it sound?" $expressivenessOptions 2 -Example "Pick the emotional temperature that fits you."
$formalityLevel = Ask-One "formality_level" "How formal should the persona be?" $formalityOptions 2 -Example "Pick the sentence that matches your workplace tone."
$relationshipVsEfficiency = Ask-One "relationship_vs_efficiency" "What should it optimize for first?" $relationshipOptions 3 -Example "Pick the sentence that best balances people and progress."
$sentenceFlow = Ask-One "sentence_flow" "What sentence flow feels most natural?" $sentenceFlowOptions 4 -Example "Pick the rhythm closest to your natural writing."

$structurePreference = Ask-One "structure_preference" "What structure do you prefer?" $structureOptions 3 -Example "Pick how your messages should usually be shaped."
$decisionStyle = Ask-Many "decision_style" "How should the agent handle decisions?" $decisionOptions @("make_clear_decisions", "offer_options") $true -Example "Pick the sentence behaviors you want from the agent."
$feedbackStyle = Ask-Many "feedback_style" "How should the agent give feedback or edits?" $feedbackOptions @("suggestion_based", "direct_correction") $true -Example "Pick the correction style that would feel useful."
$softeningLevel = Ask-One "softening_level" "How much softening should it use?" $softeningOptions 2 -Example "Pick the sentence that sounds right when disagreeing."
$greetingStyle = Ask-One "greeting_style" "How often should greetings be included?" $greetingOptions 2 -Example "Pick how much opening formality you prefer."
$signoffStyle = Ask-One "signoff_style" "How often should signoffs be included?" $signoffFrequencyOptions 2 -Example "Pick how often messages should close with a signoff."
$preferredSignoffs = @(To-List (Ask-Text "preferred_signoffs" "Preferred signoffs? Use commas. Leave blank for defaults." "Best, Thanks" $false -Example "Best, Thanks, Kind regards"))
$forbiddenSignoffs = @(To-List (Ask-Text "forbidden_signoffs" "Forbidden signoffs? Use commas. Leave blank if none." "" $false -Example "Cheers, Warmly"))
$emojiUsage = Ask-One "emoji_usage" "How often should emoji be used?" $emojiOptions 2 -Example "Pick the sentence closest to your chat style."

$collaborationModel = Ask-Many "interaction_model" "How should the agent collaborate with you?" $collaborationOptions @("ask_before_finalize", "refine_iteratively", "challenge_when_needed") $true -Example "Pick the sentences that describe how you want the agent to work."
$longerSentences = Ask-One "longer_sentences" "If your natural style uses longer sentences, should the agent keep, reduce, or remove that?" $tendencyOptions 2 -Example "Pick what should happen to long sentences."
$contextBeforeMainPoint = Ask-One "context_before_main_point" "If you give context before the main point, should the agent keep, reduce, or remove that?" $tendencyOptions 2 -Example "Pick what should happen when context buries the point."
$emotionalTone = Ask-One "emotional_tone" "If you use emotional warmth, should the agent keep, reduce, or remove that?" $tendencyOptions 1 -Example "Pick what should happen to warmth."
$overExplaining = Ask-One "over_explaining" "If you over-explain, should the agent keep, reduce, or remove that?" $tendencyOptions 2 -Example "Pick what should happen to extra explanation."

$forbiddenPatterns = @(To-List (Ask-Text "forbidden_patterns" "Words, phrases, or habits to avoid? Use commas." "hope this finds you well, just checking in, circling back" $false -Example "hope this finds you well, just checking in, circling back"))
$preferredPatterns = @(To-List (Ask-Text "preferred_patterns" "Preferred phrases or patterns? Use commas. Leave blank if none." "" $false -Example "quick update, decision needed, next step"))
$styleRules = @(To-List (Ask-Text "style_rules" "Any hard style rules? Use commas." "Lead with the main point, keep paragraphs short, include next steps when relevant" $false -Example "Lead with the main point, no corporate filler"))
$punctuationRules = @(To-List (Ask-Text "punctuation_rules" "Any punctuation rules? Use commas." "Use plain punctuation, avoid excessive exclamation marks" $false -Example "Use plain punctuation, avoid excessive exclamation marks"))
$negativeStyle = Ask-Many "negative_style" "What should the persona avoid sounding like?" $negativeOptions @("too_corporate", "too_long", "robotic", "vague") $true -Example "Pick the sentences you do not want the persona to resemble."
$optimizeFor = Ask-Many "optimize_for" "What impression should it optimize for?" $impressionOptions @("competence", "clarity", "confidence", "collaboration") $true -Example "Pick the short sentences that reflect the impression you want."
$writingExample = Ask-Text "writing_example" "Optional: paste one short example of writing that feels like you." "" $false -Example "Quick update: we are on track, but need approval by Friday."

$askBeforeFinalize = $collaborationModel -contains "ask_before_finalize"
$refineIteratively = $collaborationModel -contains "refine_iteratively"
$challengeWhenNeeded = $collaborationModel -contains "challenge_when_needed"

$mainPointDeadline = "first_two_sentences"
if ($brevityLevel -eq "concise") { $mainPointDeadline = "first_sentence" }
elseif ($brevityLevel -eq "detailed") { $mainPointDeadline = "first_paragraph" }

$defaultMode = "balanced"
if (($decisionStyle -contains "ask_questions_first") -and -not ($decisionStyle -contains "make_clear_decisions")) { $defaultMode = "collaborative" }
elseif (($decisionStyle -contains "make_clear_decisions") -and -not ($decisionStyle -contains "ask_questions_first")) { $defaultMode = "decisive" }

$temperature = 0.55
if ($expressivenessLevel -eq "neutral") { $temperature = 0.4 }
elseif ($expressivenessLevel -eq "expressive") { $temperature = 0.75 }

$frequencyPenalty = 0.1
if ($brevityLevel -eq "concise") { $frequencyPenalty = 0.2 }

$failureAvoid = @("vagueness", "robotic_phrasing", "buried_main_point", "unnecessary_jargon")
if ($negativeStyle -contains "too_long") { $failureAvoid += "over_explaining" }
if ($negativeStyle -contains "overly_soft") { $failureAvoid += "over_softening" }
if ($negativeStyle -contains "passive") { $failureAvoid += "passive_language" }
if ($negativeStyle -contains "vague") { $failureAvoid += "vagueness" }
if ($negativeStyle -contains "too_corporate") { $failureAvoid += "unnecessary_jargon" }
if ($negativeStyle -contains "robotic") { $failureAvoid += "robotic_phrasing" }
if ($negativeStyle -contains "overly_formal") { $failureAvoid += "excessive_hedging" }
$failureAvoid = Unique $failureAvoid

Write-Host ""
Write-Host "Inferred persona summary" -ForegroundColor Cyan
Write-Host "Name: $personaName"
Write-Host "Role/context: $roleTitle in $industry"
Write-Host "Audience: $(Join-Labels $audienceTypes)"
Write-Host "Tone: $(Join-Labels $coreToneTraits)"
Write-Host "Style: $(Label-Of $brevityLevel), $(Label-Of $directnessLevel), $(Label-Of $formalityLevel)"
Write-Host "Avoid: $(Join-Labels $negativeStyle)"

$confirm = Read-Host "Generate Persona.md with this profile? [Y/n]"
if (($null -ne $confirm) -and ($confirm.Trim().ToLowerInvariant() -in @("n", "no"))) {
    Write-Host "No file written."
    exit 0
}

$createdAt = Get-Date
$createdAtUtc = $createdAt.ToUniversalTime().ToString("o")
$createdAtLocal = $createdAt.ToString("yyyy-MM-dd HH:mm:ss")
$createdAtFile = $createdAt.ToString("yyyy-MM-dd HH-mm-ss")
$personaId = ($personaName.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
if ([string]::IsNullOrWhiteSpace($personaId)) { $personaId = "persona" }

$systemPrompt = @"
You are writing and operating as the persona "$personaName".

Identity:
- Native language: $nativeLanguage
- English proficiency: $(Label-Of $englishProficiency)
- Cultural style: $(Label-Of $culturalStyle)
- Role context: $roleTitle in $industry
- Seniority: $(Label-Of $seniorityBand)

Voice:
- Core tone: $(Join-Labels $coreToneTraits)
- Brevity: $(Label-Of $brevityLevel)
- Directness: $(Label-Of $directnessLevel)
- Expressiveness: $(Label-Of $expressivenessLevel)
- Formality: $(Label-Of $formalityLevel)
- Relationship vs efficiency: $(Label-Of $relationshipVsEfficiency)
- Sentence flow: $(Label-Of $sentenceFlow)

Operating rules:
- Lead with the main point within the $mainPointDeadline.
- Use short paragraphs.
- Use bullets when they improve clarity.
- Include a concrete next step when relevant.
- Ask a focused question when important context is missing.
- Make a recommendation when there is enough information.
- Challenge assumptions respectfully when they could create risk.

Communication preferences:
- Preferred structure: $(Label-Of $structurePreference)
- Decision style: $(Join-Labels $decisionStyle)
- Feedback style: $(Join-Labels $feedbackStyle)
- Softening level: $(Label-Of $softeningLevel)
- Greeting style: $(Label-Of $greetingStyle)
- Signoff style: $(Label-Of $signoffStyle)
- Emoji usage: $(Label-Of $emojiUsage)

Avoid:
$(Bullet-List $negativeStyle)

Language constraints:
$(Bullet-List $styleRules $false)
"@

if (-not [string]::IsNullOrWhiteSpace($writingExample)) {
    $systemPrompt += "`r`n`r`nReference writing sample:`r`n$writingExample"
}

$config = [ordered]@{
    schema_version = "1.0.0"
    builder_mode = "interactive_survey"
    metadata = [ordered]@{
        persona_id = $personaId
        persona_name = $personaName
        created_by = "persona-builder command"
        created_at = $createdAtUtc
        updated_at = $createdAtUtc
        notes = "Generated from local interactive survey."
        source_mode = "survey_only"
    }
    survey_profile = [ordered]@{
        questions = $script:Questions
        response_style = [ordered]@{
            ask_one_by_one = $true
            allow_multiselect = $true
            show_examples = $true
            confirm_inference_before_finalize = $true
        }
    }
    persona_profile = [ordered]@{
        identity = [ordered]@{
            native_language = $nativeLanguage
            english_proficiency = $englishProficiency
            cultural_style = $culturalStyle
            background_summary = $backgroundSummary
        }
        context = [ordered]@{
            company = $company
            industry = $industry
            department = $department
            role_title = $roleTitle
            function_area = $functionArea
            audience_types = @($audienceTypes)
            seniority_band = $seniorityBand
            primary_use_cases = @($primaryUseCases)
        }
        tone_profile = [ordered]@{
            core_tone_traits = @($coreToneTraits)
            brevity_level = $brevityLevel
            directness_level = $directnessLevel
            expressiveness_level = $expressivenessLevel
            formality_level = $formalityLevel
            relationship_vs_efficiency = $relationshipVsEfficiency
            sentence_flow = $sentenceFlow
        }
        communication_preferences = [ordered]@{
            structure_preference = $structurePreference
            decision_style = @($decisionStyle)
            feedback_style = @($feedbackStyle)
            softening_level = $softeningLevel
            greeting_style = $greetingStyle
            signoff_style = $signoffStyle
            preferred_signoffs = @($preferredSignoffs)
            forbidden_signoffs = @($forbiddenSignoffs)
            emoji_usage = $emojiUsage
        }
        cognitive_tendencies = [ordered]@{
            longer_sentences = $longerSentences
            context_before_main_point = $contextBeforeMainPoint
            emotional_tone = $emotionalTone
            over_explaining = $overExplaining
        }
        language_constraints = [ordered]@{
            forbidden_patterns = @($forbiddenPatterns)
            preferred_patterns = @($preferredPatterns)
            style_rules = @($styleRules)
            punctuation_rules = @($punctuationRules)
        }
        negative_style = @($negativeStyle)
        impression_management = [ordered]@{
            optimize_for = @($optimizeFor)
        }
    }
    behavior_profile = [ordered]@{
        communication_matrix = [ordered]@{
            intent_rules = @(
                [ordered]@{ intent = "inform"; instructions = @("Lead with the main point.", "Keep context short.", "Make the status or implication clear.") }
                [ordered]@{ intent = "align"; instructions = @("State the shared goal.", "Name the decision or tradeoff.", "Invite focused confirmation.") }
                [ordered]@{ intent = "decide"; instructions = @("Give a recommendation when enough information is available.", "Show options only when they materially change the outcome.", "End with the next step.") }
                [ordered]@{ intent = "request"; instructions = @("Be specific about the ask.", "Include deadline or priority when relevant.", "Keep the tone respectful and clear.") }
                [ordered]@{ intent = "push"; instructions = @("Be direct without sounding sharp.", "Name the concern.", "Offer a practical path forward.") }
                [ordered]@{ intent = "unblock"; instructions = @("Identify the blocker.", "Ask only for the missing input.", "Suggest the fastest next action.") }
                [ordered]@{ intent = "escalate"; instructions = @("State the risk and impact early.", "Avoid blame.", "Make the requested decision explicit.") }
                [ordered]@{ intent = "follow_up"; instructions = @("Reference the previous thread briefly.", "Restate the ask.", "Make the next step easy to answer.") }
            )
            seniority_rules = @(
                [ordered]@{ audience = "peer"; instructions = @("Use a collaborative tone.", "Keep it practical.", "Offer help or a next step.") }
                [ordered]@{ audience = "manager"; instructions = @("Lead with status, risk, or decision need.", "Be concise.", "Make tradeoffs visible.") }
                [ordered]@{ audience = "senior_manager"; instructions = @("Summarize implications first.", "Avoid excessive detail.", "Use clear recommendations.") }
                [ordered]@{ audience = "director"; instructions = @("Focus on outcome, risk, decision, and timing.", "Use crisp structure.") }
                [ordered]@{ audience = "vp"; instructions = @("Use executive-level brevity.", "Make the business implication clear.") }
                [ordered]@{ audience = "executive"; instructions = @("Start with the conclusion.", "Use confident wording.", "Keep only decision-relevant context.") }
            )
            context_rules = @(
                [ordered]@{ context = "urgent"; instructions = @("Put deadline and action first.", "Remove optional context.", "Use decisive wording.") }
                [ordered]@{ context = "normal"; instructions = @("Balance warmth and efficiency.", "Include useful context without overexplaining.") }
                [ordered]@{ context = "sensitive"; instructions = @("Use diplomatic wording.", "Avoid blame.", "Separate facts from interpretation.") }
                [ordered]@{ context = "ambiguous"; instructions = @("Ask a focused clarifying question.", "Offer a likely path if a reasonable assumption exists.") }
                [ordered]@{ context = "high_stakes"; instructions = @("Make assumptions explicit.", "Identify risk.", "Recommend review before final send.") }
            )
        }
        decision_logic = [ordered]@{
            default_mode = $defaultMode
            switch_to_decisive_when = @("sufficient_information", "clear_best_option", "request_for_recommendation", "senior_audience")
            switch_to_exploratory_when = @("ambiguous_request", "missing_context", "high_stakes_decision", "multiple_valid_options", "stakeholder_alignment_needed")
        }
        interaction_model = [ordered]@{
            ask_before_finalize = $askBeforeFinalize
            refine_iteratively = $refineIteratively
            challenge_when_needed = $challengeWhenNeeded
            adapt_to_user_answers = $true
            maintain_persona_consistency = $true
        }
        structure_rules = [ordered]@{
            lead_with_main_point = $true
            main_point_deadline = $mainPointDeadline
            use_short_paragraphs = $true
            use_bullets_when_helpful = $true
            always_include_next_step_when_relevant = $true
        }
        failure_controls = [ordered]@{
            avoid = @($failureAvoid)
            corrections = @(
                [ordered]@{ trigger = "Main point is buried"; action = "Move conclusion or request to the first sentence." }
                [ordered]@{ trigger = "Message feels robotic"; action = "Use simpler, more natural phrasing while keeping professionalism." }
                [ordered]@{ trigger = "Message is too long"; action = "Cut repeated context and keep only decision-relevant detail." }
                [ordered]@{ trigger = "Tone is too soft"; action = "Replace excessive hedging with clear, respectful wording." }
            )
        }
    }
    generation_profile = [ordered]@{
        temperature = $temperature
        top_p = 0.9
        frequency_penalty = $frequencyPenalty
        presence_penalty = 0.0
        recommended_ranges = [ordered]@{
            corporate_structured = [ordered]@{ temperature = "0.2-0.45"; top_p = "0.8-0.95"; frequency_penalty = "0.0-0.2"; presence_penalty = "0.0-0.1" }
            balanced_human = [ordered]@{ temperature = "0.45-0.7"; top_p = "0.85-0.95"; frequency_penalty = "0.0-0.3"; presence_penalty = "0.0-0.2" }
            more_expressive = [ordered]@{ temperature = "0.7-1.0"; top_p = "0.9-1.0"; frequency_penalty = "0.1-0.4"; presence_penalty = "0.0-0.3" }
        }
    }
    system_prompt_template = $systemPrompt
}

$normalizedJson = $config | ConvertTo-Json -Depth 30
$fence = '```'

$markdown = @"
# Persona: $personaName

Generated: $createdAtLocal

## Ready-To-Use System Prompt

${fence}text
$systemPrompt
${fence}

## Profile

- Native language: $nativeLanguage
- English proficiency: $(Label-Of $englishProficiency)
- Cultural style: $(Label-Of $culturalStyle)
- Industry: $industry
- Company: $(if ([string]::IsNullOrWhiteSpace($company)) { "Not specified" } else { $company })
- Department: $(if ([string]::IsNullOrWhiteSpace($department)) { "Not specified" } else { $department })
- Role title: $roleTitle
- Function area: $(if ([string]::IsNullOrWhiteSpace($functionArea)) { "Not specified" } else { $functionArea })
- Seniority: $(Label-Of $seniorityBand)
- Audience: $(Join-Labels $audienceTypes)
- Main use cases: $(Join-Labels $primaryUseCases)

## Voice And Tone

- Core tone: $(Join-Labels $coreToneTraits)
- Brevity: $(Label-Of $brevityLevel)
- Directness: $(Label-Of $directnessLevel)
- Expressiveness: $(Label-Of $expressivenessLevel)
- Formality: $(Label-Of $formalityLevel)
- Relationship vs efficiency: $(Label-Of $relationshipVsEfficiency)
- Sentence flow: $(Label-Of $sentenceFlow)

## Communication Rules

- Structure: $(Label-Of $structurePreference)
- Decision style: $(Join-Labels $decisionStyle)
- Feedback style: $(Join-Labels $feedbackStyle)
- Softening: $(Label-Of $softeningLevel)
- Greetings: $(Label-Of $greetingStyle)
- Signoffs: $(Label-Of $signoffStyle)
- Preferred signoffs: $(if (@($preferredSignoffs).Count -eq 0) { "None specified" } else { @($preferredSignoffs) -join ", " })
- Forbidden signoffs: $(if (@($forbiddenSignoffs).Count -eq 0) { "None specified" } else { @($forbiddenSignoffs) -join ", " })
- Emoji usage: $(Label-Of $emojiUsage)

## Avoid Sounding Like

$(Bullet-List $negativeStyle)

## Language Constraints

### Forbidden Patterns

$(Bullet-List $forbiddenPatterns $false)

### Preferred Patterns

$(Bullet-List $preferredPatterns $false)

### Style Rules

$(Bullet-List $styleRules $false)

### Punctuation Rules

$(Bullet-List $punctuationRules $false)

## Behavior Model

- Default decision mode: $(Label-Of $defaultMode)
- Ask before finalizing: $askBeforeFinalize
- Refine iteratively: $refineIteratively
- Challenge when needed: $challengeWhenNeeded
- Lead with main point: True
- Main point deadline: $mainPointDeadline

## Normalized Persona Config

${fence}json
$normalizedJson
${fence}
"@

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $personaFolder = Join-Path $PSScriptRoot "personas"
    $safePersonaName = Get-SafeFileName $personaName
    $OutputPath = Join-Path $personaFolder "$safePersonaName - $createdAtFile.md"
}

$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

Set-Content -LiteralPath $resolvedOutputPath -Value $markdown -Encoding UTF8

Write-Host ""
Write-Host "Persona written to:" -ForegroundColor Green
Write-Host $resolvedOutputPath
