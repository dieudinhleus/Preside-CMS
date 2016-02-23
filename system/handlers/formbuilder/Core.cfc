component {

	property name="formBuilderService"           inject="formBuilderService";
	property name="formBuilderValidationService" inject="formBuilderValidationService";
	property name="validationEngine"             inject="validationEngine";
	property name="storageProvider" 			 inject="formBuilderStorageProvider";

	public any function submitAction( event, rc, prc ) {
		var formId       = rc.form ?: "";
		var validRequest = Len( Trim( formId ) ) && Len( Trim( cgi.http_referer ) ) && event.getHTTPMethod() == "POST";

		if ( !validRequest ) {
			event.notFound();
		}
		if( structKeyExists( rc, "fileFields" ) ){
			for ( fileFieldName in rc.fileFields ){
				if( len( rc[ fileFieldName ] ) ){
					var fileName = GetPageContext().formScope().getUploadResource( fileFieldName ).getName();
					var uniqueFilename = '/'& formId & '/' & createUUID() & '/' & fileName;
					storageProvider.putObject( object = rc[fileFieldName], path = uniqueFilename );
					rc[fileFieldName] = uniqueFilename;
				}
			}
		}
		var submission       = event.getCollectionWithoutSystemVars();
		var validationResult = formBuilderService.saveFormSubmission(
			  formId      = formId
			, requestData = submission
			, instanceId  = ( rc.instanceId ?: "" )
		);

		if ( event.isAjax() ) {
			if ( validationResult.validated() ) {
				var successMessage = renderViewlet( event="formbuilder.core.successMessage", args={ formId=formId } );

				event.renderData( data={ success=true, response=successMessage }, type="json" );
			} else {
				var errors = {};
				var messages = validationResult.getMessages();
				for( var fieldName in messages ) {
					var message = messages[ fieldName ];
					errors[ fieldName ] = translateResource( uri=message.message, data=message.params );
				}
				event.renderData( data={ success=false, errors=errors }, type="json" );
			}
		} else {
			if ( validationResult.validated() ) {
				setNextEvent( url=cgi.http_referer, persistStruct={
					formBuilderFormSubmitted = formId
				} );
			} else {
				submission.validationResult = validationResult;
				setNextEvent( url=cgi.http_referer, persistStruct=submission );
			}
		}
	}

	private string function formLayout( event, rc, prc, args={} ) {
		if ( ( rc.formBuilderFormSubmitted ?: "" ) == ( args.form ?: "" ) ) {
			return renderViewlet( event="formbuilder.core.successMessage", args={ formId=args.form } )
		}

		var validationRulesetName = formBuilderValidationService.getRulesetForFormItems( args.formItems ?: [] );
		if ( validationRulesetName.len() ) {
			args.validationJs = validationEngine.getJqueryValidateJs(
				  ruleset         = validationRulesetName
				, jqueryReference = "jQuery"
			);
		}

		event.include( assetId="/js/frontend/formbuilder/" );

		return renderView( view="/formbuilder/layouts/core/formLayout", args=args );
	}

	private string function successMessage( event, rc, prc, args ) {
		args.successMessage = formBuilderService.getSubmissionSuccessMessage( args.formId ?: "" );
		args.successMessage = renderContent( renderer="richeditor", data=args.successMessage );

		return renderView( view="/formbuilder/layouts/core/successMessage", args=args );
	}

}