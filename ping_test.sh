#!/opt/bin/bash

###############################################################################################
Mypath="/opt/bin/"

Program="ping"
###############################################################################################
# Return states
st=0
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3
Flag=""

# Internal variables
TRUE=1
FALSE=0
ERROR=1
DEBUG=$FALSE
VERBOSE=$FALSE

WL=0.0
WC=0.0
WCparam=0.0
Crst=0
Wrst=0

# PING variables
PING_HOST=""
PING_SOURCE=""
PING_PACKETS=5
PING_TIMEOUT=10
PingOut="_ 0 _"
PING_PrLOSS=0

# Check variables
LEVEL_WARNING=100,10%
LEVEL_CRITICAL=500,40%
PING_PL=100 # Default value to package lost
PING_AT=0 # Default value to averange time

##########################################################################################
#source /opt/lib/check_ip.sh
##########################################################################################

check_ip() {
  local ip=$PING_HOST
  # Регулярное выражение для проверки формата IPv4
  if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    for i in {1..4}; do
      if [[ ${BASH_REMATCH[$i]} -gt 255 || ${BASH_REMATCH[$i]} -lt 0 ]]; then
        echo "Некорректный IP адрес."
        return 1
      fi
    done
#    echo "IP адрес корректен."
    return 0
  else
    echo "Некорректный формат IP адреса."
    return 1
  fi
}

##########################################################################################
help_usage() {
    echo "Usage:"
        echo " $0 -H (PING_HOST) -w (LEVEL_WARNING) -c (LEVEL_CRITICAL) -p (PING_PACKETS)"
        echo " $0 (-v | --version)"
        echo " $0 (-h | --help)"
    echo "_______________________________________________________" 
 
}
##########################################################################################
help_version() {
    echo "_______________________________________________________"
    echo "check_ping.sh ( analog nagios-plugins check_ping ) v. 0.01"
    echo "2024 Ptah57 Oziris <ptah57@mail.ru>"
}
##########################################################################################
exit_abnormal() {                         # Функция для выхода в случае ошибки.
  help_usage
  exit 2
}
##########################################################################################
check_w_arg() {
# Регулярное выражение
  regex='^[0-9]{1,4}\.[0-9]{1,2},[0-9]{1,2}%+$' 
  if [[ $LEVEL_WARNING =~ $regex ]]; then
     :
#    echo "Строка аргумента параметра -w соответствует шаблону."
  else
    echo "Строка аргумента параметра -w не соответствует шаблону."
    exit_abnormal
  fi
}
##########################################################################################
check_c_arg() {
# Регулярное выражение
  regex='^[0-9]{1,4}\.[0-9]{1,2},[0-9]{1,2}%+$'
  if [[ $LEVEL_CRITICAL =~ $regex ]]; then
     :
#    echo "Строка аргумента параметра -c соответствует шаблону."
  else
    echo "Строка аргумента параметра -c не соответствует шаблону."
    exit_abnormal
  fi
}
##############################################################################################

check_p_arg() {
# Регулярное выражение
  regex='[0-9]'
  if [[ $PING_PACKETS =~ $regex ]]; then
         :
#   echo "Строка аргумента параметра -p соответствует шаблону."
  else
    echo "Строка аргумента параметра -p не соответствует шаблону."
    exit_abnormal
fi
}
#############################################################################################
#  Вывод только для отладки
#################################################################################################
pr_deb_f() {

echo "ping_test.sh $@"
echo "--------------------------------------------------------"
echo "$Flag"
echo "WCparam=$WCparam"
echo "PING_PrLOSS=$PING_PrLOSS"
echo "LEVEL_WARNING = $LEVEL_WARNING"
echo "LEVEL_CRITICAL= $LEVEL_CRITICAL"
echo "WC = $WC"
echo "WL = $WL"
echo "Crst=$Crst"
echo "Wrst=$Wrst"
echo "--------------------------------------------------------"
}
##################################################################################################
##############################################################################################
#  Main  проверка есть ли вообще параметры
##############################################################################################
if [[ -z "$1" ]] 
then
        echo "Missing parameters! Syntax: ./`basename $0` -H PING_HOST -w (warning,%) -c (critical,%) "
	help_version
	help_usage
        exit 3
fi
##############################################################################################
if [ "$1" = "-h" -o "$1" = "--help" -o "$1" = "-v" -o "$1" = "--version" ]
then
	help_version
	echo ""
	echo "This shell plugin will check if ping host  is ok."
	echo ""
	help_usage
	echo ""
	echo "Required Arguments:"
	echo " -H HOST -w ## -c ## -p ##"
	echo ""
	exit 3
fi
##############################################################################################
##############################################################################################
#  Разбор ключей и параметров
##############################################################################################
while getopts "H:w:c:p:" options; do         # Цикл: выбора опций по одной,
               # с использованием silent-проверки
	       # ошибок. Опции -H, -w и -c -p должны
	       # принимать аргументы.
  case "${options}" in    # 
    H)                    # Если это опция H, то установка
      PING_HOST=${OPTARG}                      # $PING_HOST в указанное значение.
      check_ip
      ;;
    w)                                  # Если это опция t, то установка
      LEVEL_WARNING=${OPTARG}           # $LEVEL_WARNING в указанное значение.
      check_w_arg                       # Regex: ожидается совпадение
                                        # только с цифрами.
      ;;
    c)
      LEVEL_CRITICAL=${OPTARG}          # $LEVEL_CRITICAL в указанное значение.
      check_c_arg                       # Regex: ожидается совпадение
                                        # только с цифрами.
      ;;
    p)
      PING_PACKETS=${OPTARG}            # $PING_PACKETS в указанное значение
      check_p_arg

      ;;
    :)                                    # Если ожидаемый аргумент опущен:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                       # Ненормальный выход.
      ;;
    *)                                    # Если встретилась неизвестная опция:
      exit_abnormal                       # Ненормальный выход.
      ;;
  esac
  done

#################################################################################################
#  проверяем и выводим результат 
#################################################################################################

WL=$( echo $LEVEL_WARNING  | cut -f1 -d ',')
WC=$( echo $LEVEL_CRITICAL | cut -f1 -d ',')
PingOut="$($Mypath$Program -c $PING_PACKETS -4 $PING_HOST)"
Flag=$( echo "$PingOut" | tail -4)
WCparam="$(echo "$PingOut" | grep min/avg/max | cut -f2 -d '=' | cut -f2 -d '/' ) "
PING_PrLOSS="$(echo "$PingOut" | grep -oP '\d+(?=% packet loss)')"
Crst=$( /opt/bin/echo "$WCparam>$WC" | /opt/bin/bc -l )
Wrst=$( echo "$WCparam>$WL" | /opt/bin/bc -l )

if [ $Crst -eq 1 ] 
  then
  echo "SERVICE STATUS: CRITICAL $PingOut"
  exit $CRITICAL
fi


if [ $Wrst -eq 1 ] 
  then
  echo "SERVICE STATUS: WARNING $PingOut"
  exit $WARNING
fi

  echo "SERVICE STATUS: OK $PingOut"
  exit $OK

