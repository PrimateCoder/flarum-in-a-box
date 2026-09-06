<?php

/*
 * This file is part of pianotell/flarum-in-a-box.
 *
 * Copyright (c) 2026 Navindra Umanee
 *
 * LICENSE: For the full copyright and license information,
 * please view the LICENSE file that was distributed
 * with this source code.
 */

/*
 * Demo Auto-Confirm — Flarum-In-A-Box build-time helper.
 *
 * Auto-confirms the email address of every new signup so the demo forum
 * works without a mail server. This is the Flarum 1.x stand-in for the
 * `linkrobins/auto-verify` extension used by the 2.x edition on main
 * (which is not compatible with Flarum 1.x).
 */

use Flarum\Extend;
use Flarum\User\Event\Registered;

return [
    (new Extend\Event())->listen(Registered::class, function (Registered $event) {
        $event->user->activate();
        $event->user->save();
    }),
];
