import styles from './MapSettings.module.scss';
import { Dialog } from 'primereact/dialog';
import { useCallback, useMemo, useState } from 'react';
import { TabPanel, TabView } from 'primereact/tabview';
import { PrettySwitchbox } from './components';
import {
  InterfaceStoredSettingsProps,
  useMapRootState,
  InterfaceStoredSettings,
} from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { Dropdown } from 'primereact/dropdown';

export enum UserSettingsRemoteProps {
  link_signature_on_splash = 'link_signature_on_splash',
  select_on_spash = 'select_on_spash',
  delete_connection_with_sigs = 'delete_connection_with_sigs',
}

export const DEFAULT_REMOTE_SETTINGS = {
  [UserSettingsRemoteProps.link_signature_on_splash]: false,
  [UserSettingsRemoteProps.select_on_spash]: false,
  [UserSettingsRemoteProps.delete_connection_with_sigs]: false,
};

export const UserSettingsRemoteList = [
  UserSettingsRemoteProps.link_signature_on_splash,
  UserSettingsRemoteProps.select_on_spash,
  UserSettingsRemoteProps.delete_connection_with_sigs,
];

export type UserSettingsRemote = {
  link_signature_on_splash: boolean;
  select_on_spash: boolean;
  delete_connection_with_sigs: boolean;
};

export type UserSettings = UserSettingsRemote & InterfaceStoredSettings;

export interface MapSettingsProps {
  show: boolean;
  onHide: () => void;
}

type CheckboxesList = {
  prop: keyof UserSettings;
  label: string;
}[];

const COMMON_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: InterfaceStoredSettingsProps.isShowMinimap, label: 'Show Minimap' },
];

const SYSTEMS_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: InterfaceStoredSettingsProps.isShowKSpace, label: 'Highlight Low/High-security systems' },
  { prop: UserSettingsRemoteProps.select_on_spash, label: 'Auto-select splashed' },
];

const SIGNATURES_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: UserSettingsRemoteProps.link_signature_on_splash, label: 'Link signature on splash' },
  { prop: InterfaceStoredSettingsProps.isShowUnsplashedSignatures, label: 'Show unsplashed signatures' },
];

const CONNECTIONS_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: UserSettingsRemoteProps.delete_connection_with_sigs, label: 'Delete connections to linked signatures' },
  { prop: InterfaceStoredSettingsProps.isThickConnections, label: 'Thicker connections' },
];

const UI_CHECKBOXES_PROPS: CheckboxesList = [
  { prop: InterfaceStoredSettingsProps.isShowMenu, label: 'Enable compact map menu bar' },
  { prop: InterfaceStoredSettingsProps.isShowBackgroundPattern, label: 'Show background pattern' },
  { prop: InterfaceStoredSettingsProps.isSoftBackground, label: 'Enable soft background' },
];

const THEME_OPTIONS = [
  { label: 'Default', value: 'neon' },
  { label: 'Pathfinder', value: 'pathfinder' },
];

export const MapSettings = ({ show, onHide }: MapSettingsProps) => {
  const [activeIndex, setActiveIndex] = useState(0);

  const { outCommand, interfaceSettings, setInterfaceSettings } = useMapRootState();

  const [userRemoteSettings, setUserRemoteSettings] = useState<UserSettingsRemote>({
    ...DEFAULT_REMOTE_SETTINGS,
  });

  const mergedSettings = useMemo(() => {
    return {
      ...userRemoteSettings,
      ...interfaceSettings,
    };
  }, [userRemoteSettings, interfaceSettings]);


  const handleShow = async () => {
    const { user_settings } = await outCommand({
      type: OutCommand.getUserSettings,
      data: null,
    });
    setUserRemoteSettings({
      ...user_settings,
    });
  };

  const handleChangeChecked = useCallback(
    (prop: keyof UserSettings) => async (checked: boolean) => {
      if (UserSettingsRemoteList.includes(prop as any)) {
        const newRemoteSettings = {
          ...userRemoteSettings,
          [prop]: checked,
        };
        await outCommand({
          type: OutCommand.updateUserSettings,
          data: newRemoteSettings,
        });
        setUserRemoteSettings(newRemoteSettings);
        return;
      }

      setInterfaceSettings({
        ...interfaceSettings,
        [prop]: checked,
      });
    },
    [userRemoteSettings, interfaceSettings, outCommand, setInterfaceSettings],
  );

  const renderCheckboxesList = (list: CheckboxesList) => {
    return list.map((x) => (
      <PrettySwitchbox
        key={x.prop}
        label={x.label}
        checked={mergedSettings[x.prop]}
        setChecked={handleChangeChecked(x.prop)}
      />
    ));
  };


  const handleChangeTheme = useCallback(
    (newThemeValue: string) => {
      setInterfaceSettings({
        ...interfaceSettings,
        theme: newThemeValue,
      });
    },
    [interfaceSettings, setInterfaceSettings]
  );

  return (
    <Dialog
      header="Map user settings"
      visible={show}
      draggable={false}
      style={{ width: '550px' }}
      onShow={handleShow}
      onHide={() => {
        if (!show) return;
        setActiveIndex(0);
        onHide();
      }}
    >
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-2">
          <div className={styles.verticalTabsContainer}>
            <TabView
              activeIndex={activeIndex}
              onTabChange={(e) => setActiveIndex(e.index)}
              className={styles.verticalTabView}
            >
              <TabPanel header="Common" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">
                  {renderCheckboxesList(COMMON_CHECKBOXES_PROPS)}
                </div>
              </TabPanel>

              <TabPanel header="Systems" headerClassName={styles.verticalTabHeader}>
                <div className="w-full h-full flex flex-col gap-1">
                  {renderCheckboxesList(SYSTEMS_CHECKBOXES_PROPS)}
                </div>
              </TabPanel>

              <TabPanel header="Connections" headerClassName={styles.verticalTabHeader}>
                {renderCheckboxesList(CONNECTIONS_CHECKBOXES_PROPS)}
              </TabPanel>

              <TabPanel header="Signatures" headerClassName={styles.verticalTabHeader}>
                {renderCheckboxesList(SIGNATURES_CHECKBOXES_PROPS)}
              </TabPanel>

              <TabPanel header="User Interface" headerClassName={styles.verticalTabHeader}>
                {renderCheckboxesList(UI_CHECKBOXES_PROPS)}
              </TabPanel>

              <TabPanel header="Theme" headerClassName={styles.verticalTabHeader}>
                <div className="flex items-center gap-2 mt-2">
                  <label className="text-sm">Select Theme:</label>
                  <Dropdown
                    className="text-sm"
                    value={interfaceSettings.theme || 'neon'} // default to "neon"
                    options={THEME_OPTIONS}
                    onChange={(e) => handleChangeTheme(e.value)}
                    placeholder="Select a theme"
                  />
                </div>
              </TabPanel>
            </TabView>
          </div>
        </div>
      </div>
    </Dialog>
  );
};
