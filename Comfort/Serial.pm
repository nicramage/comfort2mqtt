use strict;

package Comfort::Serial;
use Time::HiRes qw (usleep);
use Time::Local;

our $module;
if ($^O =~ /mswin/i)
{
	eval 'use Win32::SerialPort';
	$module = 'Win32::SerialPort';
}
else
{
	eval 'use Device::SerialPort';
	$module = 'Device::SerialPort';
}

use constant QUIET => 0;

use constant BAUD => 9600;
use constant DATA_BITS => 8;
use constant STOP_BITS => 1;
use constant PARITY => "none";
use constant LOG_SEND => 1;
use constant LOG_RECEIVE => 2;


use constant STX => chr (3);
use constant CR => chr (13);

use constant MAX_READ_LENGTH => 256;
use constant READ_TIMEOUT => 5000;
use constant READ_SLEEP_INTERVAL => 50;

#CBUS Constants
use constant CBUS_RAMP_0 => 2;
use constant CBUS_RAMP_4 => 10;
use constant CBUS_RAMP_8 => 18;
use constant CBUS_RAMP_12 => 26;
use constant CBUS_RAMP_20 => 34;
use constant CBUS_RAMP_30 => 42;
use constant CBUS_RAMP_40 => 50;
use constant CBUS_RAMP_60 => 58;
use constant CBUS_RAMP_ON => 121;
use constant CBUS_RAMP_OFF => 1;
use constant CBUS_RAMP_UP => 1;
use constant CBUS_RAMP_DOWN => 121;

use constant CBUS_APPLICATION_LIGHTING => 56;
use constant CBUS_APPLICATION_SECURITY => 2;

use constant CBUS_UCM_BASE => 16;

use constant COMFORT_OUTPUT_OFF => 0;
use constant COMFORT_OUTPUT_ON => 1;
use constant COMFORT_OUTPUT_TOGGLE => 2;
use constant COMFORT_OUTPUT_PULSE => 3;
use constant COMFORT_OUTPUT_FLASH => 4;

our @REPORTS = qw (IP CT AL AM AR MD ER BP BY OP EX PT IR IX);
our %MSG_TYPES =
(
	'AL' => [ '(A2)*' ],
	'AM' => [ '(A2)*' ],
	'AR' => [ '(A2)*' ],
	'BP' => [ '(A2)*' ],
	'BY' => [ '(A2)*' ],
	'CT' => [ '(A2)(A2)' ],
	'C?' => [ '(A2)(A2)' ],
	'DT' => [ '(A4)(A2)*', \&_ToTime_t ],
	'ER' => [ '(A2)*' ],
	'EX' => [ '(A2)*' ],
	'IP' => [ '(A2)*' ],
	'IR' => [ '(A2)*' ],
	'IX' => [ '(A2)*' ],
	'MD' => [ '(A2)*' ],
	'OP' => [ '(A2)(A2)' ],
	'PT' => [ '(A2)*' ],
	'Z?' => [ '(A)*' ],
);

our %keyLookup =
(
	'0'     => '00',
	'1'     => '01',
	'2'     => '02',
	'3'     => '03',
	'4'     => '04',
	'5'     => '05',
	'6'     => '06',
	'7'     => '07',
	'8'     => '08',
	'9'     => '09',
	'F'     => '0A',
	'*'     => '0B',
	'#'     => '0C',
	'away'  => '0D',
	'night' => '0E',
	'day'   => '0F',
	'panic' => '10',
	'enter' => '1A',
);

sub new ($$)
{
	my ($class, $port) = @_;

	my $this = {};
	$this->{PORT} = $port;
	$this->{CONNECTED} = $this->{LOGGED_IN} = 0;
	$this->{LAST_ERROR_MSG} = '';
	$this->{TIMEOUT} = READ_TIMEOUT;
	$this->{REPORT_CALLBACK} = undef;
	$this->{LOG_CALLBACK} = undef;
	$this->{REPORT_CALLBACKS} = { };
	$this->{CBUS_UCM} = 2;

	bless ($this, $class);
	return $this;
}



sub SetLastErrorMsg ($$)
{
	my ($this, $msg) = @_;
	$msg ||= $^E;
	return $this->{LAST_ERROR_MSG} = $msg;
}


sub GetLastErrorMsg()
{
	my $this = shift;
	return $this->{LAST_ERROR_MSG};
}


sub SetLogger ($$)
{
	my ($this, $callback) = @_;
	$this->{LOG_CALLBACK} = $callback;
}


sub SetReportCallback ($$)
{
	my ($this, $type, $callback) = @_;
	$this->{REPORT_CALLBACKS}->{$type} = $callback;
}


sub Log ($$$)
{
	my ($this, $logType, $msg) = @_;

	if ($this->{LOG_CALLBACK})
	{
		$this->{LOG_CALLBACK} ($logType, $msg);
	}
}


sub Connect ($@)
{
	my ($this, $port) = @_;
	$port //= $this->{PORT};

	if ($this->{PORT_OBJECT})
	{
		$this->Disconnect();
	}


	my $portObj = $module->new ($port, QUIET);
	if (!$portObj)
	{
		$this->SetLastErrorMsg();
		return undef;
	}

	$this->{PORT} = $port;

	$portObj->baudrate (BAUD);
	$portObj->parity (PARITY);
	$portObj->databits (DATA_BITS);
	$portObj->stopbits (DATA_BITS);
	$portObj->read_const_time (READ_TIMEOUT);

	$portObj->are_match (STX, CR);
	$portObj->lookclear();

	$this->{PORT_OBJECT} = $portObj;
	$this->{BUFFER} = '';

	return 1;
}



sub Disconnect()
{
	my ($this) = @_;
	if ($this->{PORT_OBJECT})
	{
		$this->{PORT_OBJECT}->close();
		$this->{PORT_OBJECT} = undef;
	}

}


sub Send ($$$@)
{
	my ($this, $cmd, $msg) = @_;

	my $logMsg = $cmd . $msg;;

	my $error = undef;
	my $po = $this->{PORT_OBJECT};
	my $msg = STX . $cmd . $msg . CR;

	my $count = $po->write ($msg);
	if (!$count)
	{
		$error = "Write failed";
	}

	if ($count != length ($msg))
	{
		$error = "Incomplete write";
	}

	if ($error)
	{
		$this->SetLastErrorMsg ($error);
		$logMsg .= " Failed: $error"
	}

	$this->Log (LOG_SEND, $logMsg);

	return $error ? undef : 1;
}



sub SendAndReceive ($$$)
{
	my ($this, $cmd, $msg) = @_;
	if (! $this->Send ($cmd, $msg))
	{
		return undef;
	}

	return $this->Receive ($this->{TIMEOUT}, 1);
}



sub Receive ($)
{
	my ($this, $waiting, $ignoreReport) = @_;
	my $po = $this->{PORT_OBJECT};

	my $msg = '';
	if ($waiting)
	{
		$waiting /= READ_SLEEP_INTERVAL;
		$waiting = 1 if ($waiting <= 0);
	}
	else
	{
		$waiting = 1;
	}

	my $loopsLeft = $waiting;
	my $type = undef;
	while ($loopsLeft)
	{
		my $input = $po->input();
		$this->{BUFFER} .= $input;

		$msg = '';
		my $start = index ($this->{BUFFER}, STX);
		if ($start >= 0)
		{
			my $end = index ($this->{BUFFER}, CR, $start);
			if ($end >= 0)
			{
				$msg = substr ($this->{BUFFER}, $start + 1, $end - $start - 1);
				substr ($this->{BUFFER}, 0, $end + 1) = '';
			}
		}

		if ($msg ne '')
		{
			$this->Log (LOG_RECEIVE, $msg);

			my $handled;
			($handled, $type) = $this->_ProcessMsg ($msg);

			if (!$handled || !$ignoreReport)
			{
				$loopsLeft = 0;
				$msg = '' if ($handled);
			}
			else
			{
				$loopsLeft = $waiting;
			}
		}
		else
		{
			usleep (READ_SLEEP_INTERVAL * 1000);
			--$loopsLeft;
		}
	}

	if (wantarray)
	{
		return ($msg, $type);
	}

	return $msg;
}



sub _ToHex
{
	return map { hex } @_;
}


sub _CallReportCallback ($$$)
{
	my ($this, $type, $params) = @_;
	my $handled = 0;

	if (exists $MSG_TYPES{$type} && exists $this->{REPORT_CALLBACKS}->{$type})
	{
		my $mt = $MSG_TYPES{$type};
		my $rt = $mt->[0];
		my $fn = @$mt < 2 ? \&_ToHex : $mt->[1];

		my @params = $fn->(unpack ($rt, $params));
		$this->{REPORT_CALLBACKS}->{$type} ($type, @params);
		$handled = 1;
	}

	return $handled;
}


sub _ToTime_t
{
	my ($year, $month, $day, $hour, $min, $sec, $dst) = @_;

	return timelocal ($sec, $min, $hour, $day, $month - 1, $year);
}


sub _ProcessMsg ($$)
{
	my ($this, $msg) = @_;
	my $handled = 0;
	my $type = undef;
	if (length ($msg) >= 2)
	{
		$msg =~ /^(..)(.*)$/;
		$type = $1;

		$handled = $this->_CallReportCallback ($type, $2);
		if (! $handled)
		{
			if (grep (/^$type$/, @REPORTS))
			{
				$this->_HandleReport ($type, $msg);
				$handled = 1;
			}
		}
	}

	return ($handled, $type);
}


sub _HandleReport ($$)
{
	my ($this, $type, @params) = @_;

	if ($this->{REPORT_CALLBACK})
	{
		$this->{REPORT_CALLBACK} ($type, @params);
	}
}


sub Login ($$@)
{
	my ($this, $password, $port) = @_;
	die "Not connected" if (!$this->{PORT_OBJECT});

	if ($password ne '' && $this->{LOGGED_IN})
	{
		$this->Logout();
	}

	my $result = $this->SendAndReceive ('LI', $password);
	if ($result !~ /LU(\d\d)/ || $1 eq '00')
	{
		$this->SetLastErrorMsg ("Login Failed");
		return undef;
	}

	$this->{LOGGED_IN} = 1;
	return 1;
}


sub Logout ($)
{
	my ($this) = @_;
	my $po = $this->{PORT_OBJECT};
	if ($po && $this->{LOGGED_IN})
	{
		my $result = $this->SendAndReceive ('LI');
		if ($result ne 'LU00')
		{
			$this->SetLastErrorMsg ("Logout Failed");
			return undef;
		}

		$this->{LOGGED_IN} = 0;
	}

	return 1;
}


sub EnableReports ($$)
{
	my ($this, $callback) = @_;
	die "Not connected" if (!$this->{PORT_OBJECT});

	my $result = $this->SendAndReceive ('SR', '01');

	if ($result = ($result =~ /^OK/))
	{
		$this->{REPORT_CALLBACK} = $callback;
	}

	return $result;
}


sub DisableReports ($)
{
	my ($this) = @_;
	die "Not connected" if (!$this->{PORT_OBJECT});

	my $result = $this->SendAndReceive ('SR', '00');

	if ($result = ($result =~ /^OK/))
	{
		$this->{REPORT_CALLBACK} = undef;
	}

	return $result;
}


sub SendKey ($$)
{
	my ($this, $key) = @_;
	die "Not connected" if (!$this->{PORT_OBJECT});

	if (exists $keyLookup{$key})
	{
		my $result = $this->SendAndReceive ('KD', $keyLookup{$key});
		if ($result && $result eq 'OK')
		{
			return 1;
		}
	}

	$this->SetLastErrorMsg ("Send key '$key' Failed");
	return undef;
}



sub SetOutput ($$$)
{
	my ($this, $output, $status) = @_;
	my $result = $this->SendAndReceive (sprintf ('O!%02X%02X', $output, $status));
	if ($result && $result eq 'OK')
	{
		return 1;
	}

	$this->SetLastErrorMsg ("Set output '$output' to '$status' Failed");
	return undef;
}



sub SendCbusCommand ($$$$)
{
	my ($this, $group, $cmd, $level, $app) = @_;
	die "Not connected" if (!$this->{PORT_OBJECT});

	$cmd ||= CBUS_RAMP_OFF;
	$level ||= 0;
	$app ||= CBUS_APPLICATION_LIGHTING;

	my $levelWidth = 2;
	if ($level == 255)
	{
		$level = 0x0FFD;
		$levelWidth = 4;
	}
	elsif ($level == 15)
	{
		$level = 0x0F0F;
		$levelWidth = 4;
	}

	my $groupWidth = 2;
	if ($group == 15)
	{
		$group = 0x0F0F;
		$groupWidth = 4;
	}

	my $result = $this->SendAndReceive ('DA',
		sprintf ('C5%02X%0*X%02X%0*X%02XFF',
			$this->{CBUS_UCM} + CBUS_UCM_BASE, $groupWidth, $group, $cmd, $levelWidth, $level, $app));

	if ($result && $result eq 'RA00')
	{
		return 1;
	}

	$this->SetLastErrorMsg ("Send CBUS command Failed: " . ($result ? $result : 'No response'));
	return undef;
}

1; 
