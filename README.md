# pg2drpl

Given a PostgreSQL 12 Database Table or View,
generates a matching Drupal 8-10 Entity module,
by parsing output of 'psql' command.

## Usage:

tclsh pg2drpl.tcl "DATABASE" "PREFIX" "TABLE_OR_VIEW" "PACKAGE" "TITLE" "{REF1_FIELD REF1_ENTITY} {REF2_FIELD REF2_ENTITY} ... {REFX_FIELD REFX_ENTITY}"

## Where:

**DATABASE** - name of PostgreSQL database where the table or view is

**PREFIX** - the prefix for all Drupal tables in this database (optionally configured at Drupal site setup)

**TABLE_OR_VIEW** - the name of the table or view in the DATABASE without any PREFIX - IMPORTANT: FIRST COLUMN MUST BE PRIMARY KEY

**PACKAGE** - the local package to group this module into eg. Custom

**TITLE** - the mixed case name of the module eg. My Test PG Module

**REFX_FIELD & REFX_ENTITY** - optional pairs of fields that are Entity References on other entities (for Views)

## Example:

`tclsh pg2drpl.tcl "drupal_muh_database" "drupal10" "vw_from_afar" "MYSTUFF" "My View From Afar" "{new_uid user} {did phones}"`

## Note:

* FIRST COLUMN OF TABLE MUST BE UNIQUE KEY eg. bigserial!  pg2drpl does not check for this - CAREFUL!!
* You must have sudo installed and be able to sudo to the 'postgres' user ie. "sudo -u postgres psql" works.
* REFX_FIELD cannot be existing field name from some other entity (at least not 'uid')!
 
