class NotificationScheduler {
    constructor() {
        this.jobs = [];
    }

    /**
     * Initialize all cron jobs
     * Call this once at server startup
     */
    initialize() {
        console.log('[NotificationScheduler] V2 Schema: Scheduled notification cron jobs are disabled temporarily.');
    }

    stopAll() {
        console.log('[NotificationScheduler] Stopping all cron jobs...');
    }
}

// Export singleton instance
export default new NotificationScheduler();
