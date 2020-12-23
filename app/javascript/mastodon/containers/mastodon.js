import React from 'react';
import { Provider, connect } from 'react-redux';
import PropTypes from 'prop-types';
import configureStore from '../store/configureStore';
import { BrowserRouter, Route } from 'react-router-dom';
import { ScrollContext } from 'react-router-scroll-4';
import UI from '../features/ui';
import Introduction from '../features/introduction';
import { fetchCustomEmojis } from '../actions/custom_emojis';
import { hydrateStore } from '../actions/store';
import { connectUserStream } from '../actions/streaming';
import { IntlProvider, addLocaleData } from 'react-intl';
import { getLocale } from '../locales';
import initialState from '../initial_state';
import ErrorBoundary from '../components/error_boundary';

const { localeData, messages } = getLocale();
addLocaleData(localeData);

export const store = configureStore();
const hydrateAction = hydrateStore(initialState);

store.dispatch(hydrateAction);
store.dispatch(fetchCustomEmojis());

const mapStateToProps = state => ({
  onlyMedia: state.getIn(['settings', 'home', 'other', 'onlyMedia'])
});

@connect(mapStateToProps)
class MastodonMount extends React.PureComponent {

  static propTypes = {
    onlyMedia: PropTypes.bool
  };

  componentDidMount() {
    const { onlyMedia } = this.props;
    this.disconnect = store.dispatch(connectUserStream({ onlyMedia }));
  }

  componentDidUpdate (prevProps) {
    const { onlyMedia } = this.props;
    if (prevProps.onlyMedia !== onlyMedia) {
      this.disconnect();
      this.disconnect = store.dispatch(connectUserStream({ onlyMedia }));
    }
  }

  componentWillUnmount () {
    if (this.disconnect) {
      this.disconnect();
      this.disconnect = null;
    }
  }

  shouldUpdateScroll (prevRouterProps, { location }) {
    return !(location.state?.mastodonModalKey && location.state?.mastodonModalKey !== prevRouterProps?.location?.state?.mastodonModalKey);
  }

  render () {
    return (
      <BrowserRouter basename='/web'>
        <ScrollContext shouldUpdateScroll={this.shouldUpdateScroll}>
          <Route path='/' component={UI} />
        </ScrollContext>
      </BrowserRouter>
    );
  }

}

export default class Mastodon extends React.PureComponent {

  static propTypes = {
    locale: PropTypes.string.isRequired,
  };

  render () {
    const { locale } = this.props;

    return (
      <IntlProvider locale={locale} messages={messages}>
        <Provider store={store}>
          <ErrorBoundary>
            <MastodonMount />
          </ErrorBoundary>
        </Provider>
      </IntlProvider>
    );
  }

}
