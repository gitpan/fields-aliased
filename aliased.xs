#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define MAX_VARNAME_LENGTH 254

/*
 * $Id: aliased.xs,v 1.0 2004/09/28 02:57:30 kevin Exp $
 */

/*
 * get_object_value - retrieve the value of the given field, whether from an
 * actual hash or a pseudohash.
 */
SV *
get_object_value(pTHX_ SV *object, I32 type, SV *field, HV *index)
{
	dTHR;
	SV *value;
	const char *fieldname = SvPV_nolen(field);

	switch (type) {
		case SVt_PVHV:
			{
				HE *hval = hv_fetch_ent((HV *)object, field, 0, 0);

				if (hval == NULL)
					croak("field %s does not exist", fieldname);

				value = HeVAL(hval);
			}
			break;

		case SVt_PVAV:
			{
				HE *hval = hv_fetch_ent(index, field, 0, 0);
				SV **valptr;
				I32 i;

				if (hval == NULL)
					croak("field %s does not exist", fieldname);

				i = SvIV(HeVAL(hval));
				valptr = av_fetch((AV *)object, i, 0);
				if (valptr == NULL)
					croak("no value found for field %s", fieldname);

				value = *valptr;
			}
			break;

		default:
			croak(
				"invalid object type %d, should be %d or %d",
				type, SVt_PVHV, SVt_PVAV
			);
			break;
	}
	return (value);
}

/*
 * field_varname - convert a field name to the equivalent variable name.
 */
STRLEN
field_varname(SV *input, char *output, STRLEN output_size)
{
	I32 sigil = 0;
	STRLEN name_length;
	const char *name = SvPV(input, name_length);
	
	if (name[0] == '_')
		sigil = 1;
	
	switch (name[sigil]) {
		case '$':
		case '@':
		case '%':
			if (output_size <= name_length)
				croak("output buffer too small in field_varname");
			strcpy(output, name);
			if (sigil == 1) {
				char temp = output[0];
				output[0] = output[1];
				output[1] = temp;
			}
			break;
		
		default:
			if (output_size <= ++name_length)
				croak("output buffer too small in field_varname");
			output[0] = '$';
			strcpy(&output[1], name);
			break;
	}
	return name_length;
}

MODULE = fields::aliased		PACKAGE = fields::aliased
PROTOTYPES: disable

##==============================================================================
## setup - set up the aliases for fields::aliased
## The parameter list is a list of field names. These are converted to
## variable names, which are then aliased.
##==============================================================================
void
setup(SV *self, ...)
	INIT:
		HV *arglist = newHV();
		char varname[MAX_VARNAME_LENGTH + 2];
		int i;
		char *vnstr;
		STRLEN vnlen;
		char temp;
		SV *selfref;
		HV *pshindex;
		I32 selftype;
		AV *padv, *padn;
	CODE:
		/******************************************************************
		 * Find the CV corresponding to the current sub.
		 *****************************************************************/
		{
			U32 dummy;
			CV *cv = Perl_find_runcv(aTHX_ &dummy);
			padv = (AV *)AvARRAY(CvPADLIST(cv))[CvDEPTH(cv)];
			padn = (AV *)AvARRAY(CvPADLIST(cv))[0];
		}

		/******************************************************************
		 * Get the underlying hash for self
		 *****************************************************************/
		if (SvROK(self)) {
			selfref = SvRV(self);
			selftype = SvTYPE(selfref);

			switch (selftype) {
				case SVt_PVHV:		/* it's a real hash */
					pshindex = NULL;
					break;

				case SVt_PVAV:		/* it's probably a pseudohash */
					{
						SV **temp = av_fetch((AV *)selfref, 0, 0);

						if (temp == NULL
						 || !SvROK(*temp)
						 || SvTYPE(SvRV(*temp)) != SVt_PVHV) {
							croak("object is array but not pseudoash");
						} else {
							pshindex = (HV *)SvRV(*temp);
						}
					}
					break;
			}
		} else {
			croak("object is not a reference");
		}

		/******************************************************************
		 * Go through and convert the argument list to a hash of
		 * variable names vs. field names.
		 *****************************************************************/
		for (i = 1; i < items; ++i) {
			SV *arg = ST(i);
			char output[MAX_VARNAME_LENGTH + 1];
			STRLEN output_length;

			if (!SvPOK(arg))
				croak("item %d is not a string containing a field name", i);

			output_length = field_varname(ST(i), output, sizeof(output));
			SvREFCNT_inc(arg);
			if (hv_store(arglist, output, output_length, arg, 0) == NULL)
				SvREFCNT_dec(arg);
		}

		/******************************************************************
		 * Go through the list of pad names.  For each one that exists
		 * in the hash created above, create the appropriate alias.
		 *****************************************************************/
		for (i = 0; i <= av_len(padn); ++i) {
			SV **nameptr = av_fetch(padn, i, 0);
			HE *hent;
			SV **field;

			if (nameptr != NULL
			 && SvPOKp(*nameptr)
			 && (hent = hv_fetch_ent(arglist, *nameptr, 0, 0)) != NULL) {
				SV *field = HeVAL(hent);
				const char *name = SvPV_nolen(*nameptr);
				SV *new_sv;
				SV *val;

				/*********************************************************
				 * This pad slot has a name and that name appears in
				 * the hash we built above.	 Do a few checks to be sure
				 * the actual field exists and has the appropriate value
				 * type (hash reference for hash fields, array reference
				 * for array fields) and then create the actual alias.
				 *******************************************************/
				val = get_object_value(
					aTHX_ selfref, selftype, field, pshindex
				);

				/*********************************************************
				 * Check variable type against field type and create
				 * new_sv
				 *******************************************************/
				switch (name[0]) {
					case '$':			/* Scalar, can be anything */
						new_sv = val;
						break;

					case '@':			/* Array, must be array reference */
						if (!SvROK(val)
						 || SvTYPE(SvRV(val)) != SVt_PVAV) {
							croak("field %s must be array reference", name);
						}
						new_sv = SvRV(val);
						break;

					case '%':			/* Hash, must be hash reference */
						if (!SvROK(val)
						 || SvTYPE(SvRV(val)) != SVt_PVHV) {
							croak("field %s must be hash reference", name);
						}
						new_sv = SvRV(val);
						break;

					default:
						croak("unrecognized variable type in '%s'", name);
				}

				/*********************************************************
				 * new_sv represents the aliased value.
				 * Store it into the pad slot.
				 *******************************************************/
				av_store(padv, i, new_sv);
			}
		}
		SvREFCNT_dec((SV*)arglist);

##==============================================================================
## field2varname - convert a field name to a variable name. In most cases,
## it returns its input value unchanged.  This function is defined here mostly
## so that both the 'setup' routine and the 'import' routine use the same
## algorithm.
##==============================================================================
SV *
field2varname(SV *name)
	INIT:
		char output[MAX_VARNAME_LENGTH + 1];
		STRLEN output_length;
	CODE:
		output_length = field_varname(name, output, sizeof(output));
		RETVAL = newSVpvn(output, output_length);
	OUTPUT:
		RETVAL

##==============================================================================
## $Log: aliased.xs,v $
## Revision 1.0  2004/09/28 02:57:30  kevin
## Initial revision
##
##==============================================================================
