import React from 'react';
import { connect } from 'react-redux';
import { expandHomeTimeline } from '../../actions/timelines';
import PropTypes from 'prop-types';
import StatusListContainer from '../ui/containers/status_list_container';
import Column from '../../components/column';
import ColumnHeader from '../../components/column_header';
import { addColumn, removeColumn, moveColumn } from '../../actions/columns';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import ColumnSettingsContainer from './containers/column_settings_container';
import { Link } from 'react-router-dom';
import { fetchAnnouncements, toggleShowAnnouncements } from 'mastodon/actions/announcements';
import AnnouncementsContainer from 'mastodon/features/getting_started/containers/announcements_container';
import classNames from 'classnames';
import IconWithBadge from 'mastodon/components/icon_with_badge';

const messages = defineMessages({
  title: { id: 'column.home', defaultMessage: 'Home' },
  show_announcements: { id: 'home.show_announcements', defaultMessage: 'Show announcements' },
  hide_announcements: { id: 'home.hide_announcements', defaultMessage: 'Hide announcements' },
});

const mapStateToProps = state => {
  const onlyMedia = state.getIn(['settings', 'home', 'other', 'onlyMedia']);
  return {
    hasUnread: state.getIn(['timelines', 'home', 'unread']) > 0,
    isPartial: state.getIn(['timelines', 'home', 'isPartial']),
    hasAnnouncements: !state.getIn(['announcements', 'items']).isEmpty(),
    unreadAnnouncements: state.getIn(['announcements', 'items']).count(item => !item.get('read')),
    showAnnouncements: state.getIn(['announcements', 'show']),
    onlyMedia,
  };
};

export default @connect(mapStateToProps)
@injectIntl
class HomeTimeline extends React.PureComponent {

  static defaultProps = {
    onlyMedia: false,
  };

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
    shouldUpdateScroll: PropTypes.func,
    intl: PropTypes.object.isRequired,
    hasUnread: PropTypes.bool,
    isPartial: PropTypes.bool,
    columnId: PropTypes.string,
    multiColumn: PropTypes.bool,
    hasAnnouncements: PropTypes.bool,
    unreadAnnouncements: PropTypes.number,
    showAnnouncements: PropTypes.bool,
    onlyMedia: PropTypes.bool,
  };

  handlePin = () => {
    const { columnId, dispatch, onlyMedia } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('HOME', {other: { onlyMedia }}));
    }
  }

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  }

  handleHeaderClick = () => {
    this.column.scrollTop();
  }

  setRef = c => {
    this.column = c;
  }

  handleLoadMore = maxId => {
    const { onlyMedia } = this.props;
    this.props.dispatch(expandHomeTimeline({ maxId, onlyMedia }));
  }

  componentDidMount () {
    const { dispatch, onlyMedia, isPartial } = this.props;
    dispatch(fetchAnnouncements());
    dispatch(expandHomeTimeline({ onlyMedia }));
    this._checkIfReloadNeeded(false, isPartial);
  }

  componentDidUpdate (prevProps) {
    const { dispatch, onlyMedia, isPartial } = this.props;
    if (prevProps.onlyMedia !== onlyMedia) {
      dispatch(expandHomeTimeline({ onlyMedia }));
    } else {
      this._checkIfReloadNeeded(prevProps.isPartial, isPartial);
    }
  }

  componentWillUnmount () {
    this._stopPolling();
  }

  _checkIfReloadNeeded (wasPartial, isPartial) {
    const { dispatch, onlyMedia } = this.props;

    if (wasPartial === isPartial) {
      return;
    } else if (!wasPartial && isPartial) {
      this.polling = setInterval(() => {
        dispatch(expandHomeTimeline({ onlyMedia }));
      }, 3000);
    } else if (wasPartial && !isPartial) {
      this._stopPolling();
    }
  }

  _stopPolling () {
    if (this.polling) {
      clearInterval(this.polling);
      this.polling = null;
    }
  }

  handleToggleAnnouncementsClick = (e) => {
    e.stopPropagation();
    this.props.dispatch(toggleShowAnnouncements());
  }

  render () {
    const { intl, shouldUpdateScroll, hasUnread, columnId, multiColumn, hasAnnouncements, unreadAnnouncements, showAnnouncements, onlyMedia } = this.props;
    const pinned = !!columnId;

    let announcementsButton = null;

    if (hasAnnouncements) {
      announcementsButton = (
        <button
          className={classNames('column-header__button', { 'active': showAnnouncements })}
          title={intl.formatMessage(showAnnouncements ? messages.hide_announcements : messages.show_announcements)}
          aria-label={intl.formatMessage(showAnnouncements ? messages.hide_announcements : messages.show_announcements)}
          aria-pressed={showAnnouncements ? 'true' : 'false'}
          onClick={this.handleToggleAnnouncementsClick}
        >
          <IconWithBadge id='bullhorn' count={unreadAnnouncements} />
        </button>
      );
    }

    return (
      <Column bindToDocument={!multiColumn} ref={this.setRef} label={intl.formatMessage(messages.title)}>
        <ColumnHeader
          icon='home'
          active={hasUnread}
          title={intl.formatMessage(messages.title)}
          onPin={this.handlePin}
          onMove={this.handleMove}
          onClick={this.handleHeaderClick}
          pinned={pinned}
          multiColumn={multiColumn}
          extraButton={announcementsButton}
          appendContent={hasAnnouncements && showAnnouncements && <AnnouncementsContainer />}
        >
          <ColumnSettingsContainer />
        </ColumnHeader>

        <StatusListContainer
          trackScroll={!pinned}
          scrollKey={`home_timeline-${columnId}`}
          onLoadMore={this.handleLoadMore}
          timelineId={`home${onlyMedia ? ':media' : ''}`}
          emptyMessage={<FormattedMessage id='empty_column.home' defaultMessage='Your home timeline is empty! Visit {public} or use search to get started and meet other users.' values={{ public: <Link to='/timelines/public'><FormattedMessage id='empty_column.home.public_timeline' defaultMessage='the public timeline' /></Link> }} />}
          shouldUpdateScroll={shouldUpdateScroll}
          bindToDocument={!multiColumn}
        />
      </Column>
    );
  }

}
