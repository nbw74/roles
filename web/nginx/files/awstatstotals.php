<?php

/**
 * AWStats Totals is a simple php script to view the totals
 * (Unique visitors, Number of visits, Pages, Hits, Bandwidth)
 * for multiple sites per month with sort options.
 *
 * @author      Jeroen de Jong <jeroen@telartis.nl>
 * @copyright   2004-2010 Telartis BV
 * @version     1.18
 *
 * @link        http://www.telartis.nl/xcms/awstats
 *
 * Changelog:
 * 1.0  initial version
 * 1.1  use awstats language files to set your language
 * 1.2  register_globals setting can be off
 * 1.3  display yearly totals and last entry (Marco Gruber)
 * 1.4  use english messages when no language files found
 * 1.5  error_reporting setting can be E_ALL
 * 1.6  fixed incorrect unique visitors in year view (ConteZero)
 * 1.7  changed number and byte format
 * 1.8  added not viewed traffic, changed layout, improved reading of AWStats database
 * 1.9  define all variables (Michael Dorn)
 * 1.10 added browser language detection (based on work by Andreas Diem)
 * 1.11 fixed notice errors when no data file present (Marco Gruber)
 * 1.12 recursive reading of awstats data directory
 * 1.13 fixed trailing slashes problem with directories
 * 1.14 fixed errors when some dirs or files were not found (Reported by Sam Evans)
 * 1.15 added security checks for input parameters (Elliot Kendall)
 * 1.16 fixed month parameter 'all' to show stats in awstats
 * 1.17 fixed small problem with open_basedir (Fred Peeterman)
 * 1.18 added filter to ignore config files (Thomas Luder)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */


/*******************************************************
 * SETUP SECTION
 *******************************************************/

/**
 * Set this value to the directory where AWStats
 * saves its database and working files into.
 */
$DirData = '/var/lib/awstats';

/**
 * The URL of the AWStats script.
 */
$AWStatsURL = '/cgi-bin/awstats.pl';

/**
 * Set your language.
 * Possible value:
 *  Albanian=al, Bosnian=ba, Bulgarian=bg, Catalan=ca,
 *  Chinese (Taiwan)=tw, Chinese (Simpliefied)=cn, Czech=cz, Danish=dk,
 *  Dutch=nl, English=en, Estonian=et, Euskara=eu, Finnish=fi,
 *  French=fr, Galician=gl, German=de, Greek=gr, Hebrew=he, Hungarian=hu,
 *  Icelandic=is, Indonesian=id, Italian=it, Japanese=jp, Korean=kr,
 *  Latvian=lv, Norwegian (Nynorsk)=nn, Norwegian (Bokmal)=nb, Polish=pl,
 *  Portuguese=pt, Portuguese (Brazilian)=br, Romanian=ro, Russian=ru,
 *  Serbian=sr, Slovak=sk, Spanish=es, Swedish=se, Turkish=tr, Ukrainian=ua,
 *  Welsh=wlk.
 *  First available language accepted by browser=auto
 */
$Lang = 'auto';

/**
 * Set the location of language files.
 */
$DirLang = '/usr/share/awstats/lang';

/**
 * How to display not viewed traffic
 * Possible value: ignore, columns, sum
 */
$NotViewed = 'sum';

/**
 * How to sort.
 * Possible value:
 * config, unique, visits, pages, hits, bandwidth,
 * not_viewed_pages, not_viewed_hits, not_viewed_bandwidth
 */
$sort_default = 'visits';

/**
 * Set number format.
 */
$dec_point = '.';
$thousands_sep = ' ';

/**
 * Config names to filter. Shows all if empty array.
 */
$FilterConfigs = array();

/*
To read website configs from database, do something like:
$sql = 'SELECT config FROM users WHERE (user=...)';
$rs = mysql_query($sql);
if ($rs) while ($row = mysql_fetch_array($rs))
    $FilterConfigs[] = $row['config'];
*/

/**
 * Config names to ignore.
 */
$FilterIgnoreConfigs = array();

/*******************************************************
 * PROGRAM SECTION
 *******************************************************/

$sort  = isset($_GET['sort'])  ? preg_replace('/[^_a-z]/', '', $_GET['sort']) : $sort_default;
$year  = isset($_GET['year'])  ? (int)$_GET['year']  : date('Y');
$month = isset($_GET['month']) ? (int)$_GET['month'] : date('n');
if (!$month) {
    $month = 'all';
}

function get_config($file) {
    $r = '';
    if (preg_match('/awstats\d{6}\.(.+)\.txt/', $file, $match)) {
        $r = $match[1];
    }
    return $r;
}

function read_history($file) {
    $config = get_config($file);

    $s = '';
    // echo "file: $file \n";
    $f = fopen($file, 'r');
    while (!feof($f)) {
       $line = fgets($f, 4096);
       $s .= $line;
       if (trim($line) == 'END_TIME') {
           break;
       }
    }
    fclose($f);

    $visits_total = preg_match('/TotalVisits (\d+)/', $s, $match) ? (int)$match[1] : 0;
    $unique_total = preg_match('/TotalUnique (\d+)/', $s, $match) ? (int)$match[1] : 0;
    
    $pages_total = 0;
    $hits_total = 0;
    $bandwidth_total = 0;
    $not_viewed_pages_total = 0;
    $not_viewed_hits_total = 0;
    $not_viewed_bandwidth_total = 0;

    if (preg_match('/\nBEGIN_TIME \d+\n(.*)\nEND_TIME\n/s', $s, $match)) {
        foreach (explode("\n", $match[1]) as $row) {
            list(
                $hour,
                $pages,
                $hits,
                $bandwidth,
                $not_viewed_pages,
                $not_viewed_hits,
                $not_viewed_bandwidth
            ) = explode(' ', $row);
            $pages_total += $pages;
            $hits_total += $hits;
            $bandwidth_total += $bandwidth;
            $not_viewed_pages_total += $not_viewed_pages;
            $not_viewed_hits_total += $not_viewed_hits;
            $not_viewed_bandwidth_total += $not_viewed_bandwidth;
        }
    }

    return array(
        'config'=>$config,
        'visits'=>$visits_total,
        'unique'=>$unique_total,
        'pages'=>$pages_total,
        'hits'=>$hits_total,
        'bandwidth'=>$bandwidth_total,
        'not_viewed_pages'=>$not_viewed_pages_total,
        'not_viewed_hits'=>$not_viewed_hits_total,
        'not_viewed_bandwidth'=>$not_viewed_bandwidth_total
    );
}

function parse_dir($dir) {
    // add a trailing slash if it doesn't exist:
    if (substr($dir, -1) != '/') {
        $dir .= '/';
    }
    $files = array();
    if ($dh = @opendir($dir)) {
        while (($file = readdir($dh)) !== false) {
            if (!preg_match('/^\./s', $file)) {
                if (is_dir($dir.$file)) {
                    $newdir = $dir.$file.'/';
                    chdir($newdir);
                    $files = array_merge($files, parse_dir($newdir));
                } else {
                    $files[] = $dir.$file;
                }
            }
        }
        chdir($dir);
    }
    return $files;
}

if (!is_dir($DirData)) {
    die("Could not open directory $DirData");
}

$dirfiles = parse_dir($DirData);

$files = array();
$config = array();
$pat = $month == 'all' ? '\d{2}' : substr('0'.$month, -2);
$pat = '/awstats'.$pat.$year.'\.(.+)\.txt$/';
foreach ($dirfiles as $file) {
    if (preg_match($pat, $file, $match)) {
        $config = $match[1];
        if (!$FilterConfigs || in_array($config, $FilterConfigs) && !in_array($config, $FilterIgnoreConfigs)) {
            $configs[] = $config;
            $files[] = $file;
        }
    }
}

$visits_total = 0;
$unique_total = 0;
$pages_total = 0;
$hits_total = 0;
$bandwidth_total = 0;
$not_viewed_pages_total = 0;
$not_viewed_hits_total = 0;
$not_viewed_bandwidth_total = 0;

$rows = array();
if ($files) {
    array_multisort($configs, $files);
    $row_prev = array();
    for ($i = 0, $cnt = count($files); $i <= $cnt; $i++) {
        $row = array();
        if ($i < $cnt) {
            $row = read_history($files[$i]);

            if ($NotViewed == 'sum') {
                $row['pages'] += $row['not_viewed_pages'];
                $row['hits'] += $row['not_viewed_hits'];
                $row['bandwidth'] += $row['not_viewed_bandwidth'];
            }

            $visits_total += $row['visits'];
            $unique_total += $row['unique'];
            $pages_total += $row['pages'];
            $hits_total += $row['hits'];
            $bandwidth_total += $row['bandwidth'];
           
            if ($NotViewed == 'columns') {
                $not_viewed_pages_total += $row['not_viewed_pages'];
                $not_viewed_hits_total += $row['not_viewed_hits'];
                $not_viewed_bandwidth_total += $row['not_viewed_bandwidth'];
            }
        }
        if ( isset($row['config']) && isset($row_prev['config']) && ($row['config'] == $row_prev['config']) ) {

            $row['visits'] += $row_prev['visits'];
            $row['unique'] += $row_prev['unique'];
            $row['pages'] += $row_prev['pages']; 
            $row['hits']  += $row_prev['hits'];
            $row['bandwidth'] += $row_prev['bandwidth'];

            if ($NotViewed == 'columns') {
                $row['not_viewed_pages'] += $row_prev['not_viewed_pages'];
                $row['not_viewed_hits'] += $row_prev['not_viewed_hits'];
                $row['not_viewed_bandwidth'] += $row_prev['not_viewed_bandwidth'];
            }

        } elseif ($i > 0) {
            $rows[] = $row_prev;
        }
        $row_prev = $row;
    }
}

function multisort(&$array, $key) {
   $cmp = create_function('$a, $b',
       'if ($a["'.$key.'"] == $b["'.$key.'"]) return 0;'.
       'return ($a["'.$key.'"] > $b["'.$key.'"]) ? -1 : 1;');
   usort($array, $cmp);
}

if ($sort == 'config') {
    sort($rows);
} else {
    multisort($rows, $sort);
}

function detect_language($DirLang) {
    $Lang = '';
    foreach (explode(',', $_SERVER['HTTP_ACCEPT_LANGUAGE']) as $Lang) {
        $Lang = strtolower(trim(substr($Lang, 0, 2)));
        if (is_dir("$DirLang/awstats-$Lang.txt")) {
            break;
        } else {
            $Lang = '';
        }
    }
    if (!$Lang) {
        $Lang = 'en';
    }
    return $Lang;
}

function read_language_data($file) {
    $r = array();
    if (file_exists($file)) {
        foreach (file($file) as $line) {
            if (preg_match('/^message(\d+)=(.*)$/', $line, $match)) {
                $r[$match[1]] = $match[2];
            }
        }
    }
    return $r;
}

// remove trailing slash if there is one:
if (substr($DirLang, -1) == '/') {
    $DirLang = substr($DirLang, 0, strlen($DirLang) - 1);
}

if ($Lang == 'auto') {
    $Lang = detect_language($DirLang);
}

$message = read_language_data("$DirLang/awstats-$Lang.txt");

if (!$message) {
    $message[7]   = 'Statistics for';
    $message[10]  = 'Number of visits';
    $message[11]  = 'Unique visitors';
    $message[56]  = 'Pages';
    $message[57]  = 'Hits';
    $message[60]  = 'Jan';
    $message[61]  = 'Feb';
    $message[62]  = 'Mar';
    $message[63]  = 'Apr';
    $message[64]  = 'May';
    $message[65]  = 'Jun';
    $message[66]  = 'Jul';
    $message[67]  = 'Aug';
    $message[68]  = 'Sep';
    $message[69]  = 'Oct';
    $message[70]  = 'Nov';
    $message[71]  = 'Dec';
    $message[75]  = 'Bandwidth';
    $message[102] = 'Total';
    $message[115] = 'OK';
    $message[133] = 'Reported period';
    $message[160] = 'Viewed traffic';
    $message[161] = 'Not viewed traffic';
}

function byte_format($number, $decimals = 2) {
    global $dec_point, $thousands_sep;
    // kilo, mega, giga, tera, peta, exa, zetta, yotta
    $prefix_arr = array('', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y');
    $i = 0;
    if ($number == 0) {
        $result = 0;
    } else {
        $value = round($number, $decimals);
        while ($value > 1024) {
            $value /= 1024;
            $i++;
        }
        $result = number_format($value, $decimals, $dec_point, $thousands_sep);
    }
    $result .= ' '.$prefix_arr[$i].'B'.($i == 0 ? 'ytes' : '');
    return $result;
}

function num_format($number, $decimals = 0) {
    global $dec_point, $thousands_sep;
    return number_format($number, $decimals, $dec_point, $thousands_sep);
}


/*******************************************************
 * HTML SECTION
 *******************************************************/

?>
<!DOCTYPE HTML PUBLIC -//W3C//DTD HTML 4.01 Transitional//EN>
<html>
<head>
<title>AWStats Totals</title>
<style type="text/css">
body { font: 11px verdana,arial,helvetica,sans-serif; background-color: white }
td   { font: 11px verdana,arial,helvetica,sans-serif; text-align: center; color: black }
.l { text-align: left }
.b { background-color: #CCCCDD; padding: 2px; margin: 0 }
.d { background-color: white }
.f { font: 14px verdana,arial,helvetica }
.border { border: #ECECEC 1px solid }
a  { text-decoration: none }
a:hover { text-decoration: underline }
a.h  { color: black }
</style>
</head>
<body>

<form action="<?php echo $_SERVER['SCRIPT_NAME']; ?>">
<table class="b" border="0" cellpadding="2" cellspacing="0" width="100%">
<tr><td class="l">
<table class="d" border="0" cellpadding="8" cellspacing="0" width="100%">
<tr>
<th><?php echo $message[133]; ?>:</th>
<td class="l">
<?php
echo '<select class="f" name="month">'."\n";
for ($i = 1; $i <= 12; $i++) { 
    echo '<option value="'.$i.'"'.($month == $i ? ' selected' : '').'>'.$message[$i + 59]."\n";
}
echo '<option value="all"'.($month == 'all' ? ' selected' : '').'>-'."\n";
echo '</select>'."\n";

echo '<select class="f" name="year">'."\n";
for ($curyear = date('Y'), $i = $curyear - 4; $i <= $curyear; $i++) {
    echo '<option value="'.$i.'"'.($year == $i ? ' selected' : '').'>'.$i."\n";
}
echo '</select>'."\n";
?>
<input type="submit" class="f" value="<?php echo $message[115]; ?>">
</td></tr>
</table>
</td></tr>
</table>
</form>

<table align="center">
<?php
if ($NotViewed == 'columns'):
?>
<tr>
<td>&nbsp;
<td class="border" colspan="5"><?php echo $message[160]; ?>
<td class="border" colspan="3"><?php echo $message[161]; ?>
<tr>
<?php
endif;
$url = $_SERVER['SCRIPT_NAME']."?month=$month&year=$year&sort=";
?>
<td bgcolor="#ECECEC" class="l" nowrap>&nbsp;<a href="<?php echo $url; ?>config" class="h"><?php echo $message[7]; ?></a>
<td width="80" bgcolor="#FFB055"><a href="<?php echo $url; ?>unique" class="h"><?php echo $message[11]; ?></a>
<td width="80" bgcolor="#F8E880"><a href="<?php echo $url; ?>visits" class="h"><?php echo $message[10]; ?></a>
<td width="80" bgcolor="#4477DD"><a href="<?php echo $url; ?>pages" class="h"><?php echo $message[56]; ?></a>
<td width="80" bgcolor="#66F0FF"><a href="<?php echo $url; ?>hits" class="h"><?php echo $message[57]; ?></a>
<td width="80" bgcolor="#2EA495"><a href="<?php echo $url; ?>bandwidth" class="h"><?php echo $message[75]; ?></a>
<?php
if ($NotViewed == 'columns'):
?>
<td width="80" bgcolor="#4477DD"><a href="<?php echo $url; ?>not_viewed_pages" class="h"><?php echo $message[56]; ?></a>
<td width="80" bgcolor="#66F0FF"><a href="<?php echo $url; ?>not_viewed_hits" class="h"><?php echo $message[57]; ?></a>
<td width="80" bgcolor="#2EA495"><a href="<?php echo $url; ?>not_viewed_bandwidth" class="h"><?php echo $message[75]; ?></a>
<?php
endif;
foreach ($rows as $row):
    echo '<tr><td class="l"><a href="'.$AWStatsURL."?month=$month&year=$year&config=".
         $row['config'].'">'.$row['config'].'</a><td>'.num_format($row['unique']).
         '<td>'.num_format($row['visits']).'<td>'.num_format($row['pages']).
         '<td>'.num_format($row['hits']).'<td>'.byte_format($row['bandwidth']);
    if ($NotViewed == 'columns'):
        echo '<td>'.num_format($row['not_viewed_pages']).
             '<td>'.num_format($row['not_viewed_hits']).
             '<td>'.byte_format($row['not_viewed_bandwidth']);
    endif;
    echo "\n";
endforeach;
echo '<tr><td class="l" bgcolor="#ECECEC">&nbsp;Total<td bgcolor="#ECECEC">'.num_format($unique_total).
     '<td bgcolor="#ECECEC">'.num_format($visits_total).'<td bgcolor="#ECECEC">'.num_format($pages_total).
     '<td bgcolor="#ECECEC">'.num_format($hits_total).'<td bgcolor="#ECECEC">'.byte_format($bandwidth_total);
if ($NotViewed == 'columns'):
echo '<td bgcolor="#ECECEC">'.num_format($not_viewed_pages_total).
     '<td bgcolor="#ECECEC">'.num_format($not_viewed_hits_total).
     '<td bgcolor="#ECECEC">'.byte_format($not_viewed_bandwidth_total);
endif;
echo "\n";
?>
</table>

<br><br><center><b>AWStats Totals 1.18</b> - <a
href="http://www.telartis.nl/xcms/awstats">&copy; 2004-2010 Telartis BV</a></center><br><br>

</body>
</html>
