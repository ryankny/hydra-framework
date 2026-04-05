/**
 * Hydra Loading Screen - User Configuration
 *
 * ============================================================
 * CUSTOMISE YOUR LOADING SCREEN HERE
 * ============================================================
 *
 * Every aspect of the loading screen can be changed from this
 * single file. No need to touch HTML, CSS, or JS.
 *
 * After editing, just restart the resource or restart your server.
 */

const LOADING_CONFIG = {

    // ========================================
    // SERVER INFO
    // ========================================
    server: {
        name: 'My Hydra Server',
        // Tagline shown below the server name
        tagline: 'Powered by Hydra Framework',
        // Small description / MOTD
        description: 'Welcome to our community. Please wait while we load your experience.',
        // Server logo - path relative to nui/ folder, or a full URL
        // Set to null to use the default Hydra logo
        logo: null,
        // Logo size in pixels (width). Height is auto.
        logoSize: 120,
    },

    // ========================================
    // BACKGROUND
    // ========================================
    background: {
        // Type: 'image', 'video', 'slideshow', 'gradient'
        type: 'gradient',

        // For type 'image': path or URL
        image: null,

        // For type 'video': path or URL (mp4 recommended)
        video: null,
        // Mute video audio
        videoMuted: true,

        // For type 'slideshow': array of image paths/URLs
        slideshow: [],
        // Slideshow interval in seconds
        slideshowInterval: 8,
        // Slideshow transition: 'fade', 'slide', 'zoom'
        slideshowTransition: 'fade',

        // For type 'gradient' (default):
        gradient: 'linear-gradient(135deg, #0F0F14 0%, #1a1a2e 30%, #16213e 60%, #0F0F14 100%)',

        // Overlay darkness (0 = none, 1 = fully black). Applied over image/video/slideshow.
        overlayOpacity: 0.5,

        // Blur amount for image/video backgrounds (px)
        blur: 0,
    },

    // ========================================
    // THEME / COLORS
    // ========================================
    theme: {
        // Primary accent color (used for progress bar, highlights)
        primary: '#6C5CE7',
        // Secondary accent
        secondary: '#00CEC9',
        // Text colors
        textPrimary: '#FFFFFF',
        textSecondary: '#A0A0B8',
        textMuted: '#6C6C80',
        // Card background (glassmorphism)
        cardBg: 'rgba(22, 22, 32, 0.75)',
        cardBorder: 'rgba(255, 255, 255, 0.06)',
        // Progress bar style: 'solid', 'gradient', 'glow'
        progressStyle: 'glow',
    },

    // ========================================
    // MUSIC / AUDIO
    // ========================================
    audio: {
        // Enable background music
        enabled: false,
        // Audio file path or URL (mp3, ogg, wav)
        src: null,
        // Volume (0.0 - 1.0)
        volume: 0.3,
        // Loop audio
        loop: true,
        // Show volume control
        showControl: true,
    },

    // ========================================
    // LOADING TIPS / MESSAGES
    // ========================================
    tips: {
        // Show rotating tips
        enabled: true,
        // Rotation interval in seconds
        interval: 6,
        // Tip messages (add as many as you want)
        messages: [
            'Press F7 to toggle your HUD.',
            'Press B to toggle your seatbelt while in a vehicle.',
            'Visit the job center to find employment.',
            'Your progress is saved automatically every 5 minutes.',
            'Use /report to contact staff if you need help.',
            'Respect other players and follow the server rules.',
            'Check your phone for messages and notifications.',
            'You can customise your character at any clothing store.',
        ],
    },

    // ========================================
    // SOCIAL LINKS
    // ========================================
    socials: {
        // Set to null to hide a link
        discord: null,
        website: null,
        store: null,
        youtube: null,
        tiktok: null,
        twitter: null,
        // Custom links: { label: 'My Link', url: 'https://...', icon: 'link' }
        custom: [],
    },

    // ========================================
    // STAFF / CREDITS
    // ========================================
    credits: {
        // Show credits section
        enabled: false,
        // Staff list
        staff: [
            // { name: 'Owner Name', role: 'Owner' },
            // { name: 'Dev Name', role: 'Developer' },
        ],
    },

    // ========================================
    // RULES
    // ========================================
    rules: {
        // Show server rules panel (toggleable)
        enabled: false,
        items: [
            // 'No RDM/VDM',
            // 'Respect all players',
            // 'No exploiting or cheating',
            // 'Use common sense',
        ],
    },

    // ========================================
    // LAYOUT & ANIMATION
    // ========================================
    layout: {
        // Content position: 'center', 'left', 'right', 'bottom'
        position: 'center',
        // Show animated particles in background
        particles: true,
        // Particle count (0 to disable)
        particleCount: 30,
        // Show loading spinner
        showSpinner: true,
        // Spinner style: 'ring', 'dots', 'pulse'
        spinnerStyle: 'ring',
        // Animate content entrance
        animateEntrance: true,
        // Show Hydra "Powered by" badge (please keep this!)
        showHydraBadge: true,
    },

    // ========================================
    // CHANGELOG / NEWS
    // ========================================
    changelog: {
        // Show a changelog/news panel
        enabled: false,
        entries: [
            // { date: '2025-01-15', title: 'New Update!', text: 'Added new vehicles and jobs.' },
        ],
    },

    // ========================================
    // ADVANCED: CUSTOM CSS
    // ========================================
    // Inject raw CSS for full customisation without editing files
    customCSS: '',

    // ========================================
    // ADVANCED: CUSTOM HTML
    // ========================================
    // Inject raw HTML into the loading screen body (after all other content)
    customHTML: '',
};
