import apiClient from 'panoptes-client/lib/api-client';
import counterpart from 'counterpart';

counterpart.setFallbackLocale('en');


const translations = {
  strings: {
    project: {},
    workflow: {}
  },
  load: (translated_type, translated_id, language) => {
    translations.strings[translated_type] = {};
    return apiClient
      .type('translations')
      .get({ translated_type, translated_id, language })
      .then(([translation]) => {
        translations.strings[translated_type] = translation.strings;
        counterpart.setLocale(language);
      })
      .catch(error => {
        console.log(error.status);
        switch (error.status) {
          case 404:
            translations.strings[translated_type] = {};
            break;
        }
      });
  }
};

export default translations;
