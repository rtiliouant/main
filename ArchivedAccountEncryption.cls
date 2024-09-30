public without sharing class ArchivedAccountEncryption {
    private static final Set<String> FIELDS_TO_ENCRYPT = new Set<String>{ 
        'Name', 'BillingStreet', 'BillingCity', 'BillingState', 'BillingPostalCode',
        'BillingCountry', 'Phone', 'Website', 'Description'
    };

    private static final Map<String, Integer> FIELD_MAX_LENGTHS = new Map<String, Integer>{
        'Name' => 255,
        'BillingStreet' => 255,
        'BillingCity' => 40,
        'BillingState' => 80,
        'BillingPostalCode' => 20,
        'BillingCountry' => 80,
        'Phone' => 40,
        'Website' => 255,
        'Description' => 32000
    };

    @InvocableMethod(label='Encrypt Account Data' description='Encrypts specified fields on Account records')
    public static void encryptAccountData(List<Account> accounts) {
        if (accounts.isEmpty()) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
        List<Account> accountsToUpdate = new List<Account>();
        List<String> errors = new List<String>();
        
        for (Account account : accounts) {
            boolean hasChanges = false;
            for (String fieldName : FIELDS_TO_ENCRYPT) {
                if (!fieldMap.containsKey(fieldName)) continue;
                
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                if (!fieldDescribe.isAccessible() || !fieldDescribe.isUpdateable()) continue;
                
                String fieldValue = (String)account.get(fieldName);
                if (String.isNotBlank(fieldValue)) {
                    try {
                        Integer maxLength = FIELD_MAX_LENGTHS.get(fieldName);
                        String encryptedValue = EncryptionUtil.encrypt(fieldValue, maxLength);
                        
                        // Truncate if necessary
                        if (encryptedValue.length() > maxLength) {
                            encryptedValue = encryptedValue.substring(0, maxLength);
                            errors.add('Warning: Encrypted value for ' + fieldName + ' on Account ' + account.Id + ' was truncated.');
                        }
                        
                        account.put(fieldName, encryptedValue);
                        hasChanges = true;
                    } catch (Exception e) {
                        errors.add('Error encrypting ' + fieldName + ' on Account ' + account.Id + ': ' + e.getMessage());
                    }
                }
            }
            if (hasChanges) {
                accountsToUpdate.add(account);
            }
        }

        // Perform the update to persist the changes
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;
            } catch (DmlException e) {
                for (Integer i = 0; i < e.getNumDml(); i++) {
                    errors.add('Error updating Account ' + e.getDmlId(i) + ': ' + e.getDmlMessage(i));
                }
            }
        }

        // Log all errors and warnings
        for (String error : errors) {
            System.debug(LoggingLevel.ERROR, error);
        }
    }
}
