package control

import (
	"errors"
	"fmt"
	"time"

	"github.com/koding/klient/Godeps/_workspace/src/github.com/koding/kite"
	"github.com/koding/klient/fix"
	"github.com/koding/klient/protocol"
)

const (
	// exitDelay is the amount of time `klient.stop` will wait before
	// actually running the uninstall logic. See Stop() docstring for
	// more information.
	exitDelay = 100 * time.Millisecond

	stopCommand     string = "service klient stop"
	overrideCommand string = "touch /etc/init/klient.override"
)

// Disconnect implements the `klient.disconnect` method, to stop klient
// from running remotely. This is tightly integrated with Ubuntu, due to
// upstart usage.
//
// It's important to note that Disconnect() does not (and should not)
// immediately stop klient. Doing so would prevent the caller from
// getting any sort of a response. So, the actual command is delayed
// by the time specified in exitDelay.
//
// TODO: Find a way to stop Klient *after* it has safely finished any
// pre-existing tasks.
func Disconnect(r *kite.Request) (interface{}, error) {
	if protocol.Environment != "managed" {
		return nil, errors.New(fmt.Sprintf(
			"klient.disconnect cannot be run from the '%s' Environment",
			protocol.Environment,
		))
	}

	err := fix.RunAsSudo(overrideCommand)
	if err != nil {
		return nil, err
	}

	go func() {
		time.Sleep(exitDelay)
		fix.RunAsSudo(stopCommand)
	}()

	return nil, nil
}
