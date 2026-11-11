import { Injectable, NgZone, inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService } from './auth.service';

const EVENTS = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart'];

@Injectable({ providedIn: 'root' })
export class IdleService {
  private auth = inject(AuthService);
  private snack = inject(MatSnackBar);
  private zone = inject(NgZone);

  private readonly timeoutMs = 30 * 60_000; // 30 minutes
  private readonly warnMs = 60_000;         // warn 1 minute before
  private lastActivity = Date.now();
  private timer?: ReturnType<typeof setInterval>;
  private warned = false;

  private onActivity = () => {
    this.lastActivity = Date.now();
    if (this.warned) this.zone.run(() => { this.warned = false; this.snack.dismiss(); });
  };

  start(): void {
    this.stop();
    this.lastActivity = Date.now();
    this.zone.runOutsideAngular(() => {
      EVENTS.forEach(e => document.addEventListener(e, this.onActivity, { passive: true }));
      this.timer = setInterval(() => this.check(), 5000);
    });
  }

  stop(): void {
    EVENTS.forEach(e => document.removeEventListener(e, this.onActivity));
    if (this.timer) clearInterval(this.timer);
    this.warned = false;
  }

  private check(): void {
    const idle = Date.now() - this.lastActivity;
    if (idle >= this.timeoutMs) {
      this.zone.run(() => { this.stop(); this.snack.dismiss(); this.auth.logout('idle'); });
    } else if (idle >= this.timeoutMs - this.warnMs && !this.warned) {
      this.zone.run(() => {
        this.warned = true;
        this.snack.open('You will be logged out in 1 minute due to inactivity.', 'Stay signed in', { duration: this.warnMs })
          .onAction().subscribe(() => this.onActivity());
      });
    }
  }
}
