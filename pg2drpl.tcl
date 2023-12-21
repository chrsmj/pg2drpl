#!/usr/bin/tclsh
#
# pg2drpl
#
# Given a PostgreSQL 12 Database Table or View,
# generates a matching Drupal 8-10 Entity module,
# by parsing output of 'psql' command.
#
# Copyright (c) 2022 Penguin PBX Solutions
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if { [llength $argv] < 5 } {
  puts "
Usage:
  tclsh pg2drpl.tcl \"DATABASE\" \"PREFIX\" \"TABLE_OR_VIEW\" \"PACKAGE\" \"TITLE\" \"\{REF1_FIELD REF1_ENTITY\} \{REF2_FIELD REF2_ENTITY\} ... \{REFX_FIELD REFX_ENTITY\}\"

Where:
  DATABASE - name of PostgreSQL database where the table or view is
  PREFIX - the prefix for all Drupal tables in this database (optionally configured at Drupal site setup)
  TABLE_OR_VIEW - the name of the table or view in the DATABASE without any PREFIX - IMPORTANT: FIRST COLUMN MUST BE PRIMARY KEY
  PACKAGE - the local package to group this module into eg. Custom
  TITLE - the mixed case name of the module eg. My Test PG Module
  REFX_FIELD & REFX_ENTITY - optional pairs of fields that are Entity References on other entities (for Views)

Example:
  tclsh pg2drpl.tcl \"drupal_muh_database\" \"drupal10\" \"vw_from_afar\" \"MYSTUFF\" \"My View From Afar\" \"{new_uid user} {did phones}\"

Note:
  * You must have sudo installed and be able to sudo to the 'postgres' user.
  * FIRST COLUMN OF TABLE MUST BE UNIQUE KEY eg. bigserial!
  * REFX_FIELD cannot be existing field name from some other entity (at least not 'uid')!
" 
  exit
}

set pdbn [lindex $argv 0]
set prfx [lindex $argv 1]
set dtbl [lindex $argv 2]
set dpkg [lindex $argv 3]
set dmod [lindex $argv 4]
set lfes [lindex $argv 5]

# drupal limit
if { [string length $dmod] > 32 } {
  puts "TITLE '${dmod}' is too long! Must be less than 32 characters."
  puts "Exiting..."
  exit
}

# TODO: could be a bug with just uid
foreach fe $lfes {
  set f [lindex [split $fe] 0]
  if { [string match "uid" $f] } {
    puts "REFX_FIELD cannot be existing field name from some other entity (at least not 'uid')!"
    puts "Exiting..."
    exit
  }
}

set ptbl $dtbl
if { [string length [string trim $prfx]] > 0 } {
  set ptbl "${prfx}_${dtbl}"
}

set xlwr [string map {" " "_"} [string tolower $dmod]]
set xhyp [string map {" " "-"} [string tolower $dmod]]
set xmxd [string map {" " ""} $dmod]

set now [clock seconds]
set odir "/tmp/pg2drpl-${now}/${xlwr}"

puts "Generating files for Drupal module in directory: ${odir}"
puts "Copy it to your custom modules directory: cp -a ${odir} /var/www/muh.example.com/web/modules/custom/"
puts "Then clear your cache with Drush: /var/www/muh.example.com/vendor/bin/drush cr"
puts "Finally enable the module with Drush: /var/www/muh.example.com/vendor/bin/drush en ${xlwr}"

file mkdir "${odir}/templates" "${odir}/src/Entity"

set finfo "${odir}/${xlwr}.info.yml"
set fperms "${odir}/${xlwr}.permissions.yml"
set flinksmenu "${odir}/${xlwr}.links.menu.yml"
set flinkstask "${odir}/${xlwr}.links.task.yml"
set fmodule "${odir}/${xlwr}.module"
set ftwig "${odir}/templates/${xhyp}.html.twig"
set finterface "${odir}/src/${xmxd}Interface.php"
set flistbuilder "${odir}/src/${xmxd}ListBuilder.php"
set fentity "${odir}/src/Entity/${xmxd}.php"


set fd [open $finfo w]
puts $fd [string trim "
name: ${dmod}
type: module
description: 'Wrapper for ${dmod} auto-generated by pg2drpl'
package: ${dpkg}
core: 8.x
core_version_requirement: ^8 || ^9 || ^10
"]
close $fd


set fd [open $fperms w]
puts $fd [string trim "
access ${xlwr} overview:
  title: 'Access ${xlwr} overview page'
"]
close $fd


set fd [open $flinksmenu w]
close $fd


set fd [open $flinkstask w]
puts $fd [string trim "
entity.${xlwr}.view:
  title: View
  route_name: entity.${xlwr}.canonical
  base_route: entity.${xlwr}.canonical
entity.${xlwr}.collection:
  title: ${dmod}
  route_name: entity.${xlwr}.collection
  base_route: system.admin_content
  weight: 10
"]
close $fd


set fd [open $fmodule w]
puts $fd [string trim "
<?php

/**
 * @file
 * Provides a ${dmod} entity type.
 */

use Drupal\\Core\\Render\\Element;

/**
 * ${xlwr}_theme().
 */
function ${xlwr}_theme() {
  return \[
    '${xlwr}' => \[
      'render element' => 'elements',
    \],
  \];
}

/**
 * Prepares variables for ${dmod} templates.
 *
 * Default template: ${xhyp}.html.twig.
 *
 * @param array \$variables
 *   An associative array containing:
 *   - elements: An associative array containing the ${dmod} information
 *     and any fields attached to the entity.
 *   - attributes: HTML attributes for the containing element.
 */
function template_preprocess_${xlwr}(array &\$variables) {
  foreach (Element::children(\$variables\['elements'\]) as \$key) {
    \$variables\['content'\]\[\$key\] = \$variables\['elements'\]\[\$key\];
  }
}
"]
close $fd


set fd [open $ftwig w]
puts $fd [string trim "
{#
/**
 * @file
 * Default theme implementation to present a ${dmod} entity.
 *
 * This template is used when viewing a registered ${dmod} page,
 * e.g., /admin/content/${xhyp}/123. 123 being the ${dmod} ID.
 *
 * Available variables:
 * - content: A list of content items. Use 'content' to print all content, or
 *   print a subset such as 'content.title'.
 * - attributes: HTML attributes for the container element.
 *
 * @see template_preprocess_${xlwr}()
 */
#}
<article{{ attributes }}>
  {% if content %}
    {{- content -}}
  {% endif %}
</article>
"]
close $fd


set fd [open $finterface w]
puts $fd [string trim "
<?php

namespace Drupal\\${xlwr};

use Drupal\\Core\\Entity\\ContentEntityInterface;

/**
 * Provides an interface defining a ${dmod} entity type.
 */
interface ${xmxd}Interface extends ContentEntityInterface {

}
"]
close $fd


set fd [open $flistbuilder w]
puts $fd [string trim "
<?php

namespace Drupal\\${xlwr};

use Drupal\\Core\\Entity\\EntityInterface;
use Drupal\\Core\\Entity\\EntityListBuilder;
use Drupal\\Core\\Datetime\\DateFormatterInterface;
use Drupal\\Core\\Entity\\EntityStorageInterface;
use Drupal\\Core\\Entity\\EntityTypeInterface;
use Drupal\\Core\\Routing\\RedirectDestinationInterface;
use Symfony\\Component\\DependencyInjection\\ContainerInterface;

/**
 * Provides a list controller for the ${dmod} entity type.
 */
class ${xmxd}ListBuilder extends EntityListBuilder {

  /**
   * The date formatter service.
   *
   * @var \\Drupal\\Core\\Datetime\\DateFormatterInterface
   */
  protected \$dateFormatter;

  /**
   * The redirect destination service.
   *
   * @var \\Drupal\\Core\\Routing\\RedirectDestinationInterface
   */
  protected \$redirectDestination;

  /**
   * Constructs a new ${xmxd}ListBuilder object.
   *
   * @param \\Drupal\\Core\\Entity\\EntityTypeInterface \$entity_type
   *   The entity type definition.
   * @param \\Drupal\\Core\\Entity\\EntityStorageInterface \$storage
   *   The entity storage class.
   * @param \\Drupal\\Core\\Datetime\\DateFormatterInterface \$date_formatter
   *   The date formatter service.
   * @param \\Drupal\\Core\\Routing\\RedirectDestinationInterface \$redirect_destination
   *   The redirect destination service.
   */
  public function __construct(EntityTypeInterface \$entity_type, EntityStorageInterface \$storage, DateFormatterInterface \$date_formatter, RedirectDestinationInterface \$redirect_destination) {
    parent::__construct(\$entity_type, \$storage);
    \$this->dateFormatter = \$date_formatter;
    \$this->redirectDestination = \$redirect_destination;
  }

  /**
   * {@inheritdoc}
   */
  public static function createInstance(ContainerInterface \$container, EntityTypeInterface \$entity_type) {
    return new static(
      \$entity_type,
      \$container->get('entity_type.manager')->getStorage(\$entity_type->id()),
      \$container->get('date.formatter'),
      \$container->get('redirect.destination')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function render() {
    \$build\['table'\] = parent::render();

    \$total = \$this->getStorage()
      ->getQuery()
      ->count()
      ->execute();

    \$build\['summary'\]\['#markup'\] = \$this->t('Total ${xmxd}es: @total', \['@total' => \$total\]);
    return \$build;
  }

  /**
   * {@inheritdoc}
   */
  public function buildHeader() {
    \$header\['id'\] = \$this->t('ID');
    return \$header + parent::buildHeader();
  }

  /**
   * {@inheritdoc}
   */
  public function buildRow(EntityInterface \$entity) {
    /* @var \$entity \\Drupal\\${xlwr}\\${xmxd}Interface */
    \$row\['id'\] = \$entity->toLink();
    return \$row + parent::buildRow(\$entity);
  }

  /**
   * {@inheritdoc}
   */
  protected function getDefaultOperations(EntityInterface \$entity) {
    \$operations = parent::getDefaultOperations(\$entity);
    \$destination = \$this->redirectDestination->getAsArray();
    foreach (\$operations as \$key => \$operation) {
      \$operations\[\$key\]\['query'\] = \$destination;
    }
    return \$operations;
  }

}
"]
close $fd



catch {exec sudo -u postgres psql -d $pdbn -c "\\d ${ptbl}" | tail -n +4 | head -n -1 | cut -f1,2 -d| | sed "s/ //g"} out

set i 20
set idcol ""
set fd [open $fentity w]
puts $fd [string trim "
<?php

namespace Drupal\\${xlwr}\\Entity;

use Drupal\\Core\\Entity\\ContentEntityBase;
use Drupal\\Core\\Entity\\EntityTypeInterface;
use Drupal\\Core\\Field\\BaseFieldDefinition;
use Drupal\\${xlwr}\\${xmxd}Interface;

/**
 * Defines the ${dmod} entity class.
 *
 * @ContentEntityType(
 *   id = \"${xlwr}\",
 *   label = @Translation(\"${dmod}\"),
 *   label_collection = @Translation(\"${dmod}es\"),
 *   handlers = {
 *     \"view_builder\" = \"Drupal\\Core\\Entity\\EntityViewBuilder\",
 *     \"list_builder\" = \"Drupal\\${xlwr}\\${xmxd}ListBuilder\",
 *     \"views_data\" = \"Drupal\\views\\EntityViewsData\",
 *     \"route_provider\" = {
 *       \"html\" = \"Drupal\\Core\\Entity\\Routing\\AdminHtmlRouteProvider\",
 *     }
 *   },
 *   base_table = \"${dtbl}\",
 *   admin_permission = \"access ${xlwr} overview\",
"]
foreach kv [split $out "\n"] {
  set k [lindex [split $kv "|"] 0]
  if { [string match "could not change directory to*" $k] } {
    break
  }
  if { [string length $idcol] == 0 } {
    set idcol $k
    puts $fd [string trimright "\
 *   entity_keys = \{
 *     \"id\" = \"${idcol}\",
 *     \"label\" = \"${idcol}\"
 *   \},
 *   links = \{
 *     \"canonical\" = \"/${xlwr}/{${xlwr}}\",
 *     \"collection\" = \"/admin/content/${xhyp}\"
 *   \},
 * )
 */
class ${xmxd} extends ContentEntityBase implements ${xmxd}Interface \{

  /**
   * {@inheritdoc}
   */
  public static function baseFieldDefinitions(EntityTypeInterface \$entity_type) \{

    \$fields = parent::baseFieldDefinitions(\$entity_type);
"]

  }
  set v [lindex [split $kv "|"] end]
  set t "string"
  set u "string"
  set x ""
  foreach fe $lfes {
    set f [lindex [split $fe] 0]
    set e [lindex [split $fe] 1]
    if { [string length $f] > 0 && [string length $e] > 0 && $k == $f } {
      set t "entity_reference"
      set v $t
      set x "      ->setSetting('target_type', '$e')
      ->setSetting('handler','default')
      ->setDisplayConfigurable('form',TRUE)
      ->setDisplayConfigurable('view',TRUE)
      ->setReadOnly(TRUE);"
    }
  }
  if { $v == "integer" } {
    set t "integer"
    set u $t
  } elseif { $v == "smallint" } {
    set t "integer"
    set u $t
  } elseif { $v == "bigint" } {
    set t "integer"
    set u $t
  } elseif { $v == "numeric(20,2)" } {
    set t "decimal"
    set u "number_decimal"
    set x "->setSettings(array('precision' => 20, 'scale' => 2,))"
  } elseif { $v == "boolean" } {
    set t "boolean"
    set u $t
  } elseif { $v == "date" } {
    # TODO: why does Drupal not like this ?
    # TODO: is it only the MySQL date that is problematic ?
    #set t "datetime"
    set t "string"
    set u $t
  } elseif { [string match "timestamp*" $v] } {
    # TODO: why does Drupal MySQL not like this ?  Only PostgreSQL does ?
    #set t "datetime"
    # needs to be string if MySQL
    # TODO: make switch based on view being foreign data wrapper
    set t "string"
    set u $t
  } elseif { $v == "uuid" } {
    set t "uuid"
  } elseif { $v == "entity_reference" } {
    # already handled
  } elseif { [string match "charactervarying*" $v] } {
    # string, the default
  } elseif { $v == "text" } {
    # string, the default
  } elseif { $v == "name" } {
    # string, the default (database user name)
  } else {
    # should never get here
    puts "OOPS $v"
  }
  puts $fd "
    \$fields\['$k'\] = BaseFieldDefinition::create('$t')
      ->setLabel(t('$k'))
      ->setDescription(t('$k'))"
  if { $t == "entity_reference" } {
    puts $fd $x
  } else {
    puts $fd "      ->setDisplayOptions('view', \[
        'type' => '$t',
        'label' => 'above',
        'weight' => $i,
      \])${x}
      ->setDisplayConfigurable('view', TRUE)
      ->setDisplayConfigurable('form', TRUE);"
  }
  incr i 5
}
puts $fd "
  return \$fields;
  \}

\}"
close $fd

