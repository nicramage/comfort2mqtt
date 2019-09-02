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

# CBUS Lighting level values
use constant CBUS_LEVEL_OFF         => 0;
use constant CBUS_LEVEL_ON          => 255;
use constant CBUS_LEVEL_5_PERCENT   => int (255*0.05);
use constant CBUS_LEVEL_10_PERCENT  => int (255*0.10);
use constant CBUS_LEVEL_20_PERCENT  => int (255*0.20);
use constant CBUS_LEVEL_25_PERCENT  => int (255*0.25);
use constant CBUS_LEVEL_30_PERCENT  => int (255*0.30);
use constant CBUS_LEVEL_40_PERCENT  => int (255*0.40);
use constant CBUS_LEVEL_50_PERCENT  => int (255*0.50);
use constant CBUS_LEVEL_60_PERCENT  => int (255*0.60);
use constant CBUS_LEVEL_70_PERCENT  => int (255*0.70);
use constant CBUS_LEVEL_75_PERCENT  => int (255*0.75);
use constant CBUS_LEVEL_80_PERCENT  => int (255*0.80);
use constant CBUS_LEVEL_90_PERCENT  => int (255*0.90);

use constant CBUS_APPLICATION_LIGHTING => 56;
use constant CBUS_APPLICATION_SECURITY => 2;
use constant CBUS_APPLICATION_TRIGGER  => 202;
use constant CBUS_APPLICATION_ENABLE   => 203;

use constant CBUS_UCM_BASE => 16;

use constant COMFORT_KEY_AWAY  => 'away';
use constant COMFORT_KEY_NIGHT => 'night';
use constant COMFORT_KEY_DAY   => 'day';
use constant COMFORT_KEY_PANIC => 'panic';
use constant COMFORT_KEY_ENTER => 'enter';

use constant COMFORT_INPUT_OFF           => 0;
use constant COMFORT_INPUT_ON            => 1;
use constant COMFORT_INPUT_SHORT_CIRCUIT => 2;
use constant COMFORT_INPUT_OPEN_CIRCUIT  => 3;

use constant COMFORT_OUTPUT_OFF => 0;
use constant COMFORT_OUTPUT_ON => 1;
use constant COMFORT_OUTPUT_TOGGLE => 2;
use constant COMFORT_OUTPUT_PULSE => 3;
use constant COMFORT_OUTPUT_FLASH => 4;

use constant COMFORT_DEFAULT_INPUT_COUNT => 32;

use constant COMFORT_ARM_OFF => 0;
use constant COMFORT_ARM_AWAY => 1;
use constant COMFORT_ARM_NIGHT => 2;
use constant COMFORT_ARM_DAY => 3;
use constant COMFORT_ARM_VACATION => 4;

use constant COMFORT_USER_NONE => 0;
use constant COMFORT_USER_KEYPAD => 240;

use constant COMFORT_ENTRY_ALERT => 1;
use constant COMFORT_EXIT_DELAY => 2;

use constant COMFORT_STATE_IDLE                => 0;
use constant COMFORT_STATE_TROUBLE             => 1;
use constant COMFORT_STATE_ALERT               => 2;
use constant COMFORT_STATE_ALARM               => 3;

use constant COMFORT_PARAMETER_NONE            => 0;
use constant COMFORT_PARAMETER_ZONE            => 1;
use constant COMFORT_PARAMETER_USER            => 2;
use constant COMFORT_PARAMETER_ID              => 3;

use constant COMFORT_ALARM_NONE                => -1;
use constant COMFORT_ALARM_INTRUDER            => 0;
use constant COMFORT_ALARM_ZONE_TROUBLE        => 1;
use constant COMFORT_ALARM_LOW_BATTERY         => 2;
use constant COMFORT_ALARM_POWER_FAIL          => 3;
use constant COMFORT_ALARM_PHONE_TROUBLE       => 4;
use constant COMFORT_ALARM_DURESS              => 5;
use constant COMFORT_ALARM_ARM_FAIL            => 6;
use constant COMFORT_ALARM_SYSTEM_DISARMED     => 8;
use constant COMFORT_ALARM_SYSTEM_ARMED        => 9;
use constant COMFORT_ALARM_TAMPER              => 10;
use constant COMFORT_ALARM_ENTRY_WARNING       => 12;
use constant COMFORT_ALARM_ALARM_ABORT         => 13;
use constant COMFORT_ALARM_SIREN_TAMPER        => 14;
use constant COMFORT_ALARM_BYPASS              => 15;
use constant COMFORT_ALARM_DIAL_TEST           => 17;
use constant COMFORT_ALARM_ENTRY_ALERT         => 19;
use constant COMFORT_ALARM_FIRE                => 20;
use constant COMFORT_ALARM_PANIC               => 21;
use constant COMFORT_ALARM_GSM_TROUBLE         => 22;
use constant COMFORT_ALARM_NEW_MESSAGE         => 23;
use constant COMFORT_ALARM_DOORBELL            => 24;
use constant COMFORT_ALARM_COMMUNICATIONS_FAIL => 25;
use constant COMFORT_ALARM_SIGNIN_TAMPER       => 26;

use constant COMFORT_ALARM_ZONE_ALERT          => 50;
use constant COMFORT_ALARM_GAS                 => 51;
use constant COMFORT_ALARM_FAMILY_CARE         => 52;
use constant COMFORT_ALARM_PERIMETER_ALERT     => 53;
use constant COMFORT_ALARM_CMS_TEST            => 54;
use constant COMFORT_ALARM_HOMESAFE            => 55;
use constant COMFORT_ALARM_ENGINEER_SIGNIN     => 56;
use constant COMFORT_ALARM_UNUSED              => 57;

use constant COMFORT_TROUBLE_BIT_AC_FAILURE    => 1 << 8;
use constant COMFORT_TROUBLE_BIT_LOW_BATTERY   => 1 << 9;
use constant COMFORT_TROUBLE_BIT_ZONE          => 1 << 10;
use constant COMFORT_TROUBLE_BIT_RS485         => 1 << 11;
use constant COMFORT_TROUBLE_BIT_TAMPER        => 1 << 12;
use constant COMFORT_TROUBLE_BIT_PHONE         => 1 << 13;
use constant COMFORT_TROUBLE_BIT_GSM           => 1 << 14;


our %ALARM_TYPES =
(
	 0 => COMFORT_ALARM_NONE,
	 1 => COMFORT_ALARM_INTRUDER,
	 2 => COMFORT_ALARM_DURESS,
	 3 => COMFORT_ALARM_PHONE_TROUBLE,
	 4 => COMFORT_ALARM_ARM_FAIL,
	 5 => COMFORT_ALARM_ZONE_TROUBLE,
	 6 => COMFORT_ALARM_ZONE_ALERT,
	 7 => COMFORT_ALARM_LOW_BATTERY,
	 8 => COMFORT_ALARM_POWER_FAIL,
	 9 => COMFORT_ALARM_PANIC,
	10 => COMFORT_ALARM_ENTRY_ALERT,
	11 => COMFORT_ALARM_TAMPER,
	12 => COMFORT_ALARM_FIRE,
	13 => COMFORT_ALARM_GAS,
	14 => COMFORT_ALARM_FAMILY_CARE,
	15 => COMFORT_ALARM_PERIMETER_ALERT,
	16 => COMFORT_ALARM_BYPASS,
	17 => COMFORT_ALARM_SYSTEM_DISARMED,
	18 => COMFORT_ALARM_CMS_TEST,
	19 => COMFORT_ALARM_SYSTEM_ARMED,
	20 => COMFORT_ALARM_ALARM_ABORT,
	21 => COMFORT_ALARM_ENTRY_WARNING,
	22 => COMFORT_ALARM_SIREN_TAMPER,
	23 => COMFORT_ALARM_UNUSED,
	24 => COMFORT_ALARM_COMMUNICATIONS_FAIL,
	25 => COMFORT_ALARM_DOORBELL,
	26 => COMFORT_ALARM_HOMESAFE,
	27 => COMFORT_ALARM_DIAL_TEST,
	28 => COMFORT_ALARM_GSM_TROUBLE,
	29 => COMFORT_ALARM_NEW_MESSAGE,
	30 => COMFORT_ALARM_ENGINEER_SIGNIN,
	31 => COMFORT_ALARM_SIGNIN_TAMPER,
);


our @REPORTS = qw (IP CT AL AM AR MD ER BP BY OP PS EX PT IR IX);
our %MSG_TYPES =
(
	'a?' => [ '(A2)(A2)(A4)(A2)*' ],
	'AL' => [ '(A2)*', \&_ToAlarmType ],
	'AM' => [ '(A2)*' ],
	'AR' => [ '(A2)*' ],
	'BP' => [ '(A2)*' ],
	'BY' => [ '(A2)*' ],
	'CT' => [ '(A2)(A2)' ],
	'C?' => [ '(A2)(A2)' ],
	'DT' => [ '(A4)(A2)*', \&_ToTime_t ],
	'ER' => [ '(A2)*' ],
	'EX' => [ '(A2)(A2)' ],
	'IP' => [ '(A2)*' ],
	'IR' => [ '(A2)*' ],
	'IX' => [ '(A2)*' ],
	'MD' => [ '(A2)(A2)' ],
	'M?' => [ '(A2)(A2)' ],
	'OP' => [ '(A2)(A2)' ],
	'O?' => [ '(A2)(A2)' ],
	'PS' => [ '(A2)' ],
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
	$this->{INPUT_COUNT} = COMFORT_DEFAULT_INPUT_COUNT;
	$this->{REPORT_CALLBACKS} =
	{
		'Z?' => \&_HandleAllZonesReport
	};
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


sub SetMaximumInputs ($$)
{
	my ($this, $count) = @_;
	$this->{INPUT_COUNT} = $count;
}


sub GetMaximumInputs ($$)
{
	my ($this) = @_;
	return $this->{INPUT_COUNT};
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
	$msg = STX . $cmd . $msg . CR;

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



sub SendAndReceive ($$$$)
{
	my ($this, $cmd, $msg, $match) = @_;
	if (! $this->Send ($cmd, $msg))
	{
		return undef;
	}

	return $this->Receive ($this->{TIMEOUT}, $match);
}



sub Receive ($)
{
	my ($this, $waiting, $match) = @_;
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
			if (defined ($match))
			{
				if (index ($msg, $match) == 0)
				{
					last;
				}
			}


			($handled, $type) = $this->_ProcessMsg ($msg);

			if (!$handled || !$match)
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



sub _ToHex (@)
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
		$this->{REPORT_CALLBACKS}->{$type} ($this, $type, @params);
		$handled = 1;
	}

	return $handled;
}


sub _ToAlarmType
{
	my (@params) = _ToHex (@_);
	my $alarmType = shift @params;
	return ( (exists ($ALARM_TYPES{$alarmType}) ? $ALARM_TYPES{$alarmType} : $alarmType + 100), @params );
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


sub _HandleAllZonesReport
{
	my ($this, $type, @zones) = @_;
	my $zone = 1;
	foreach my $zones (@zones)
	{
		for (my $i = 0;  $i < 4 && $zone <= $this->{INPUT_COUNT};  ++$i, $zones >>= 1, ++$zone)
		{
			$this->_CallReportCallback ('IP', sprintf ('%02X%02X', $zone, $zones & 1));
		}
	}
}


sub _HandleReport ($$)
{
	my ($this, $type, @params) = @_;

	if ($this->{REPORT_CALLBACK})
	{
		$this->{REPORT_CALLBACK} ($this, $type, @params);
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

	my $result = $this->SendAndReceive ('LI', $password, 'LU');
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
		my $result = $this->SendAndReceive ('LI', '', 'LU');
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

	my $result = $this->SendAndReceive ('SR', '01', 'OK');

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

	my $result = $this->SendAndReceive ('SR', '00', 'OK');

	if ($result = ($result =~ /^OK/))
	{
		$this->{REPORT_CALLBACK} = undef;
	}

	return $result;
}


sub SetDateTime ($$)
{
	my ($this, $tm) = @_;
	my ($sec, $min, $hour, $day, $month, $year) = localtime ($tm);
	my $result = $this->SendAndReceive ('DT',
		sprintf ('%04u%02u%02u%02u%02u%02u', $year + 1900, $month + 1, $day, $hour, $min, $sec), 'OK');
	if ($result && $result eq 'OK')
	{
		return 1;
	}

	$this->SetLastErrorMsg ("Set date/time to '" . scalar (localtime ($tm)) . "' Failed");
	return undef;
}


sub RequestAlarmInformationReport ($)
{
	my ($this) = @_;
	$this->Send ('a?');
}


sub RequestSecurityModeReport ($)
{
	my ($this) = @_;
	$this->Send ('M?');
}


sub RequestInputReports ($)
{
	my ($this) = @_;
	$this->Send ('Z?');
}


sub SetArmMode ($$$)
{
	my ($this, $mode, $userCode, $remote) = @_;
	my $cmd = $remote ? 'M!' : 'm!';

	my $result = $this->SendAndReceive ($cmd, sprintf ('%02X%s', $mode, $userCode), 'OK');
	if ($result && $result eq 'OK')
	{
		return 1;
	}

	$this->SetLastErrorMsg (($remote ? 'Remote' : 'Local')." arm to mode $mode failed.");
	return undef;
}


sub SendKey ($$)
{
	my ($this, $key) = @_;
	die "Not connected" if (!$this->{PORT_OBJECT});

	if (exists $keyLookup{$key})
	{
		my $result = $this->SendAndReceive ('KD', $keyLookup{$key}, 'OK');
		if ($result && $result eq 'OK')
		{
			return 1;
		}
	}

	$this->SetLastErrorMsg ("Send key '$key' Failed");
	return undef;
}


sub BypassZone ($$$)
{
	my ($this, $zone, $onOff) = @_;
	my $cmd = sprintf ($onOff ? '4B%02X' : '4C%02X', $zone);

	my $result = $this->SendAndReceive ('DA', $cmd, 'RA');

	if ($result && $result eq 'RA00')
	{
		return 1;
	}

	$this->SetLastErrorMsg (($onOff ? 'Bypass' : 'Unbypass') . " zone $zone failed");
	return undef;
}


sub SetOutput ($$$)
{
	my ($this, $output, $status) = @_;
	my $result = $this->SendAndReceive ('O!', sprintf ('%02X%02X', $output, $status), 'OK');
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
			$this->{CBUS_UCM} + CBUS_UCM_BASE, $groupWidth, $group, $cmd, $levelWidth, $level, $app), 'RA');

	if ($result && $result eq 'RA00')
	{
		return 1;
	}

	$this->SetLastErrorMsg ("Send CBUS command Failed: " . ($result ? $result : 'No response'));
	return undef;
}

1;
